//
//  KeychainHelper.swift
//  Resonance
//
//  Secure storage for sensitive tokens (Spotify access/refresh tokens, etc.)
//  Uses the iOS Keychain instead of UserDefaults for security.
//

import Foundation
import Security

enum KeychainHelper {
    
    // MARK: - Keychain Keys
    
    static let spotifyAccessToken = "com.sep.Resonance.spotifyAccessToken"
    static let spotifyRefreshToken = "com.sep.Resonance.spotifyRefreshToken"
    static let codeVerifier = "com.sep.Resonance.codeVerifier"
    
    // MARK: - Save
    
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add the new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Read
    
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    // MARK: - Delete
    
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Delete All App Tokens
    
    static func deleteAll() {
        delete(key: spotifyAccessToken)
        delete(key: spotifyRefreshToken)
        delete(key: codeVerifier)
    }
    
    // MARK: - Migration from UserDefaults
    
    /// One-time migration of tokens from UserDefaults to Keychain.
    /// Call this on app launch to migrate existing users seamlessly.
    static func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        
        // Migrate access token
        if let accessToken = defaults.string(forKey: "spotify_access_token") {
            save(key: spotifyAccessToken, value: accessToken)
            defaults.removeObject(forKey: "spotify_access_token")
        }
        
        // Migrate refresh token
        if let refreshToken = defaults.string(forKey: "spotify_refresh_token") {
            save(key: spotifyRefreshToken, value: refreshToken)
            defaults.removeObject(forKey: "spotify_refresh_token")
        }
        
        // Migrate code verifier
        if let verifier = defaults.string(forKey: "code_verifier") {
            save(key: codeVerifier, value: verifier)
            defaults.removeObject(forKey: "code_verifier")
        }
    }
}
