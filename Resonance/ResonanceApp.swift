//
//  ResonanceApp.swift
//  Resonance
//
//  Created by Sepehr on 19/11/2025.
//

import SwiftUI

@main
struct ResonanceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    handleSpotifyCallback(url: url)
                }
        }
    }
    
    func handleSpotifyCallback(url: URL) {
        guard url.scheme == "myapp" else { return }
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            if let code = queryItems.first(where: { $0.name == "code" })?.value {
                exchangeCodeForToken(code: code)
            }
        }
    }
    
    func exchangeCodeForToken(code: String) {
        guard let codeVerifier = UserDefaults.standard.string(forKey: "code_verifier") else {
            return
        }
        
        let clientId = Secrets.spotifyClientId
        let redirectUri = Secrets.spotifyRedirectUri
        
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "client_id": clientId,
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }
                
                if let accessToken = json["access_token"] as? String {
                    UserDefaults.standard.set(accessToken, forKey: "spotify_access_token")
                    
                    if let refreshToken = json["refresh_token"] as? String {
                        UserDefaults.standard.set(refreshToken, forKey: "spotify_refresh_token")
                    }
                }
            } catch {
                // Token exchange failed — user will need to log in again
            }
        }
    }
}
