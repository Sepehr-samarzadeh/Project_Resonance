//
//  CodeGen.swift
//  Resonance
//
//  Created by Sepehr on 10/12/2025.
//

import Foundation
import CryptoKit
import UIKit


func generateRandomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var result = ""
    
    for _ in 0..<length {
        if let random = letters.randomElement() {
            result.append(random)
        }
    }
    return result
}

func sha256(_ input: String) -> Data {
    let data = Data(input.utf8)
    let digest = SHA256.hash(data: data)
    return Data(digest)
}


func base64URLencode(_ data: Data) -> String {
    let base64 = data.base64EncodedString()
    
    return base64
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}


func generateCodeChallenge(from verifier: String) -> String {
    let hash = sha256(verifier)
    return base64URLencode(hash)
}



@MainActor func startSpotifyAuthorization() {
    let clientId = Secrets.spotifyClientId
    let redirectUri = Secrets.spotifyRedirectUri
    let scope = "user-read-private user-read-email user-read-currently-playing user-read-playback-state"
    
    
    let codeVerifier = generateRandomString(length: 128)
    let codeChallenge = generateCodeChallenge(from: codeVerifier)
    
    UserDefaults.standard.set(codeVerifier, forKey: "code_verifier")
    

    var components = URLComponents(string: "https://accounts.spotify.com/authorize")
    components?.queryItems = [
        URLQueryItem(name: "response_type", value: "code"),
        URLQueryItem(name: "client_id", value: clientId),
        URLQueryItem(name: "scope", value: scope),
        URLQueryItem(name: "code_challenge_method", value: "S256"),
        URLQueryItem(name: "code_challenge", value: codeChallenge),
        URLQueryItem(name: "redirect_uri", value: redirectUri)
    ]
    
   
    if let authURL = components?.url {
        print("Auth URL : \(authURL.absoluteString)")
        UIApplication.shared.open(authURL)
    }
    
}

