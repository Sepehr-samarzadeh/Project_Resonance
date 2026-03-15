//
//  ResonanceApp.swift
//  Resonance
//
//  Created by Sepehr on 19/11/2025.
//

import SwiftUI
import FirebaseAuth

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
                .task {
                    // Migrate tokens from UserDefaults to Keychain (one-time)
                    KeychainHelper.migrateFromUserDefaultsIfNeeded()
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
        guard let codeVerifier = KeychainHelper.read(key: KeychainHelper.codeVerifier) else {
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
        
        request.httpBody = urlEncodedFormData(bodyParams)
        
        Task { @MainActor in
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                
                if let raw = String(data: data, encoding: .utf8) {
                    print("[LOGIN] Token exchange response: \(raw.prefix(500))")
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("[LOGIN] Failed to parse token exchange JSON")
                    return
                }
                
                if let error = json["error"] as? String {
                    print("[LOGIN] Token exchange error: \(error) - \(json["error_description"] ?? "")")
                    return
                }
                
                if let accessToken = json["access_token"] as? String {
                    KeychainHelper.save(key: KeychainHelper.spotifyAccessToken, value: accessToken)
                    print("[LOGIN] Access token saved to Keychain")
                    
                    if let refreshToken = json["refresh_token"] as? String {
                        KeychainHelper.save(key: KeychainHelper.spotifyRefreshToken, value: refreshToken)
                        print("[LOGIN] Refresh token saved to Keychain")
                    }
                    
                    // Sign in with Firebase Anonymous Auth
                    do {
                        let uid = try await AuthManager.shared.ensureAuthenticated()
                        print("[LOGIN] Firebase Auth succeeded, UID: \(uid)")
                    } catch {
                        print("[LOGIN] Firebase Auth failed: \(error.localizedDescription)")
                        // Continue anyway -- Spotify auth succeeded
                    }
                    
                    // Register user so current_user_id is set before we notify
                    do {
                        let spotifyUser = try await SpotifyAPIManager.shared.getCurrentUserProfile()
                        print("[LOGIN] Got Spotify profile: \(spotifyUser.id)")
                        let registered = await UserManager.shared.registerUser(spotifyUser: spotifyUser)
                        print("[LOGIN] registerUser returned: \(registered)")
                        print("[LOGIN] current_user_id is now: \(UserManager.shared.getCurrentUserId() ?? "nil")")
                    } catch {
                        print("[LOGIN] Profile fetch failed: \(error)")
                    }
                    
                    print("[LOGIN] Posting didCompleteSpotifyLogin notification")
                    NotificationCenter.default.post(name: .didCompleteSpotifyLogin, object: nil)
                } else {
                    print("[LOGIN] No access_token in response. Keys: \(json.keys)")
                }
            } catch {
                print("[LOGIN] Token exchange network error: \(error)")
            }
        }
    }
}
