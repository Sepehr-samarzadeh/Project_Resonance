//
//  SpotifyAPIManager.swift
//  Resonance
//
//  Created by Sepehr on 14/12/2025.
//


import Foundation

@MainActor
class SpotifyAPIManager {
    static let shared = SpotifyAPIManager()
    
    private init() {}
    
    func getAccessToken() -> String? {
        return UserDefaults.standard.string(forKey: "spotify_access_token")
    }
    
    func getCurrentUserProfile(completion: @escaping (Result<SpotifyUser, Error>) -> Void) {
        guard let accessToken = getAccessToken() else {
            completion(.failure(NSError(domain: "No access token", code: 401)))
            return
        }
        
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: 500)))
                return
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw profile response: \(responseString)")
            }
            
            do {
                let user = try JSONDecoder().decode(SpotifyUser.self, from: data)
                completion(.success(user))
            } catch {
                print("Decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func getCurrentlyPlaying(completion: @escaping (Result<SpotifyCurrentlyPlaying, Error>) -> Void) {
        guard let accessToken = getAccessToken() else {
            completion(.failure(NSError(domain: "No access token", code: 401)))
            return
        }
        
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    // 204 = No content playing
                    print("Nothing playing right now")
                    completion(.failure(NSError(domain: "Nothing playing", code: 204)))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: 500)))
                return
            }
            
            
            do {
                let playing = try JSONDecoder().decode(SpotifyCurrentlyPlaying.self, from: data)
                completion(.success(playing))
            } catch {
                print("Decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON: \(jsonString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
}
