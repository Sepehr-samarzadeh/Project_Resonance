import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }
    
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        print("Scene received URL contexts")
        if let url = URLContexts.first?.url {
            handleIncomingURL(url)
        }
    }
    
    func handleIncomingURL(_ url: URL) {
        print("Received callback URL: \(url.absoluteString)")
        
        guard url.scheme == "myapp" else {
            print(" Invalid URL scheme")
            return
        }
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            if let code = queryItems.first(where: { $0.name == "code" })?.value {
                print("Spotify AUTH CODE: \(code)")
                // Exchange code for token
                exchangeCodeForToken(code: code)
            }
            
            if let error = queryItems.first(where: { $0.name == "error" })?.value {
                print(" Spotify Error: \(error)")
            }
        }
    }
    
    func exchangeCodeForToken(code: String) {
        guard let codeVerifier = UserDefaults.standard.string(forKey: "code_verifier") else {
            print(" No code verifier found")
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Token exchange error: \(error)")
                return
            }
            
            if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print(" Token response: \(json)")
                    
                    if let accessToken = json["access_token"] as? String {
                        print(" Access Token: \(accessToken)")
                        UserDefaults.standard.set(accessToken, forKey: "spotify_access_token")
                    }
                } else if let responseString = String(data: data, encoding: .utf8) {
                    print(" Raw response: \(responseString)")
                }
            }
        }.resume()
    }
}
