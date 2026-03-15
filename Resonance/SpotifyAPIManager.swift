//
//  SpotifyAPIManager.swift
//  Resonance
//
//  Created by Sepehr on 14/12/2025.
//

import Foundation

/// Properly percent-encodes a dictionary for application/x-www-form-urlencoded bodies.
/// Raw string interpolation breaks when values contain +, =, &, or other reserved characters.
func urlEncodedFormData(_ params: [String: String]) -> Data? {
    var components = URLComponents()
    components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
    // URLComponents.percentEncodedQuery percent-encodes per RFC 3986.
    // The "+" character is valid in query strings but means " " in form encoding,
    // so we must also encode it.
    let encoded = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    return encoded?.data(using: .utf8)
}

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
        return KeychainHelper.read(key: KeychainHelper.spotifyAccessToken)
    }
    
    // MARK: - Token Refresh
    
    func refreshAccessToken() async -> Bool {
        guard let refreshToken = KeychainHelper.read(key: KeychainHelper.spotifyRefreshToken) else {
            return false
        }
        
        guard !isRefreshing else {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return getAccessToken() != nil
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        let clientId = Secrets.spotifyClientId
        
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]
        
        request.httpBody = urlEncodedFormData(bodyParams)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                return false
            }
            
            KeychainHelper.save(key: KeychainHelper.spotifyAccessToken, value: accessToken)
            
            if let newRefreshToken = json["refresh_token"] as? String {
                KeychainHelper.save(key: KeychainHelper.spotifyRefreshToken, value: newRefreshToken)
            }
            
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - API Calls with Auto-Refresh
    
    private func makeAuthenticatedRequest(url: URL, retryOnUnauthorized: Bool = true) async throws -> (Data, HTTPURLResponse) {
        guard let accessToken = getAccessToken() else {
            print("[API] No access token in Keychain")
            throw SpotifyError.noAccessToken
        }
        
        print("[API] Request: \(url.path) (token: \(accessToken.prefix(20))...)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.noData
        }
        
        print("[API] Response: \(url.path) -> \(httpResponse.statusCode) (\(data.count) bytes)")
        
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            if let body = String(data: data, encoding: .utf8) {
                print("[API] Error body: \(body.prefix(500))")
            }
        }
        
        // Token expired — try refreshing once
        if httpResponse.statusCode == 401 && retryOnUnauthorized {
            print("[API] 401 - attempting token refresh...")
            let refreshed = await refreshAccessToken()
            if refreshed {
                return try await makeAuthenticatedRequest(url: url, retryOnUnauthorized: false)
            } else {
                throw SpotifyError.tokenRefreshFailed
            }
        }
        
        return (data, httpResponse)
    }
    
    func getCurrentUserProfile() async throws -> SpotifyUser {
        let url = URL(string: "https://api.spotify.com/v1/me")!
        let (data, _) = try await makeAuthenticatedRequest(url: url)
        return try JSONDecoder().decode(SpotifyUser.self, from: data)
    }
    
    func getCurrentlyPlaying() async throws -> SpotifyCurrentlyPlaying {
        let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        let (data, httpResponse) = try await makeAuthenticatedRequest(url: url)
        
        if httpResponse.statusCode == 204 {
            throw SpotifyError.nothingPlaying
        }
        
        do {
            return try JSONDecoder().decode(SpotifyCurrentlyPlaying.self, from: data)
        } catch {
            throw SpotifyError.decodingError(error)
        }
    }
    
    // MARK: - Top Artists (for richer matching)
    
    func getTopArtists(limit: Int = 10, timeRange: String = "medium_term") async throws -> [SpotifyArtistFull] {
        let url = URL(string: "https://api.spotify.com/v1/me/top/artists?limit=\(limit)&time_range=\(timeRange)")!
        let (data, _) = try await makeAuthenticatedRequest(url: url)
        let response = try JSONDecoder().decode(SpotifyTopArtistsResponse.self, from: data)
        return response.items
    }
    
    // MARK: - Recently Played
    
    func getRecentlyPlayed(limit: Int = 20) async throws -> [SpotifyPlayHistoryItem] {
        let url = URL(string: "https://api.spotify.com/v1/me/player/recently-played?limit=\(limit)")!
        let (data, _) = try await makeAuthenticatedRequest(url: url)
        let response = try JSONDecoder().decode(SpotifyRecentlyPlayedResponse.self, from: data)
        return response.items
    }
}
