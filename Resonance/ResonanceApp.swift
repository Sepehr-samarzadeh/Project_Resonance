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
                    print("RECEIVED URL: \(url.absoluteString)")
                    handleSpotifyCallback(url: url)
                }
        }
    }
    
    func handleSpotifyCallback(url: URL) {
        print("Handling Spotify callback")
        
        guard url.scheme == "myapp" else {
            print(" Wrong scheme: \(url.scheme ?? "none")")
            return
        }
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            if let code = queryItems.first(where: { $0.name == "code" })?.value {
                print(" GOT SPOTIFY AUTH CODE: \(code)")
                exchangeCodeForToken(code: code)
            }
            
            if let error = queryItems.first(where: { $0.name == "error" })?.value {
                print("Spotify Error: \(error)")
            }
        }
    }
    
    func exchangeCodeForToken(code: String) {
        guard let codeVerifier = UserDefaults.standard.string(forKey: "code_verifier") else {
            print(" No code verifier found")
            return
        }
        
        print("Exchanging code for token...")
        
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(" Token exchange error: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status: \(httpResponse.statusCode)")
            }
            
            if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Token response: \(json)")
                    
                    if let accessToken = json["access_token"] as? String {
                        print(" ACCESS TOKEN RECEIVED!")
                        UserDefaults.standard.set(accessToken, forKey: "spotify_access_token")
                        
                        if let refreshToken = json["refresh_token"] as? String {
                            UserDefaults.standard.set(refreshToken, forKey: "spotify_refresh_token")
                        }
                    }
                } else if let responseString = String(data: data, encoding: .utf8) {
                    print(" Raw response: \(responseString)")
                }
            }
        }.resume()
    }
}
