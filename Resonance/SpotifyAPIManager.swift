//
//  SpotifyAPIManager.swift
//  Resonance
//
//  Created by Sepehr on 14/12/2025.
//

import Foundation

enum SpotifyError: LocalizedError {
    case noAccessToken
    case noRefreshToken
    case tokenRefreshFailed
    case nothingPlaying
    case networkError(Error)
    case decodingError(Error)
    case noData
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .noAccessToken: return "Not connected to Spotify. Please log in."
        case .noRefreshToken: return "Session expired. Please log in again."
        case .tokenRefreshFailed: return "Could not refresh session. Please log in again."
        case .nothingPlaying: return "Nothing is playing right now."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError: return "Unexpected response from Spotify."
        case .noData: return "No response from Spotify."
        case .httpError(let code): return "Spotify returned error \(code)."
        }
    }
}

@MainActor
class SpotifyAPIManager {
    static let shared = SpotifyAPIManager()
    
    private var isRefreshing = false
    
    private init() {}
    
    func getAccessToken() -> String? {
        return UserDefaults.standard.string(forKey: "spotify_access_token")
    }
    
    // MARK: - Token Refresh
    
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = UserDefaults.standard.string(forKey: "spotify_refresh_token") else {
            completion(false)
            return
        }
        
        guard !isRefreshing else {
            // Already refreshing, wait a bit and check again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                completion(self.getAccessToken() != nil)
            }
            return
        }
        
        isRefreshing = true
        
        let clientId = Secrets.spotifyClientId
        
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]
        
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self?.isRefreshing = false
                }
            }
            
            if error != nil {
                completion(false)
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                completion(false)
                return
            }
            
            UserDefaults.standard.set(accessToken, forKey: "spotify_access_token")
            
            // Spotify may return a new refresh token
            if let newRefreshToken = json["refresh_token"] as? String {
                UserDefaults.standard.set(newRefreshToken, forKey: "spotify_refresh_token")
            }
            
            completion(true)
        }.resume()
    }
    
    // MARK: - API Calls with Auto-Refresh
    
    private func makeAuthenticatedRequest(url: URL, retryOnUnauthorized: Bool = true, completion: @escaping (Result<(Data, HTTPURLResponse), SpotifyError>) -> Void) {
        guard let accessToken = getAccessToken() else {
            completion(.failure(.noAccessToken))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.noData))
                return
            }
            
            // Token expired — try refreshing once
            if httpResponse.statusCode == 401 && retryOnUnauthorized {
                self?.refreshAccessToken { success in
                    if success {
                        self?.makeAuthenticatedRequest(url: url, retryOnUnauthorized: false, completion: completion)
                    } else {
                        completion(.failure(.tokenRefreshFailed))
                    }
                }
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            completion(.success((data, httpResponse)))
        }.resume()
    }
    
    func getCurrentUserProfile(completion: @escaping (Result<SpotifyUser, Error>) -> Void) {
        let url = URL(string: "https://api.spotify.com/v1/me")!
        
        makeAuthenticatedRequest(url: url) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success((let data, _)):
                do {
                    let user = try JSONDecoder().decode(SpotifyUser.self, from: data)
                    completion(.success(user))
                } catch {
                    completion(.failure(SpotifyError.decodingError(error)))
                }
            }
        }
    }
    
    func getCurrentlyPlaying(completion: @escaping (Result<SpotifyCurrentlyPlaying, Error>) -> Void) {
        let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        
        makeAuthenticatedRequest(url: url) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success((let data, let httpResponse)):
                if httpResponse.statusCode == 204 {
                    completion(.failure(SpotifyError.nothingPlaying))
                    return
                }
                
                do {
                    let playing = try JSONDecoder().decode(SpotifyCurrentlyPlaying.self, from: data)
                    completion(.success(playing))
                } catch {
                    completion(.failure(SpotifyError.decodingError(error)))
                }
            }
        }
    }
}
