//
//  AuthManager.swift
//  Resonance
//
//  Manages Firebase Anonymous Authentication.
//  Provides a Firebase Auth identity so Firestore Security Rules can
//  enforce `request.auth != null` and protect user data.
//

import Foundation
import FirebaseAuth

@MainActor
class AuthManager {
    static let shared = AuthManager()
    
    private init() {}
    
    /// The current Firebase Auth user, if signed in.
    var currentUser: User? {
        Auth.auth().currentUser
    }
    
    /// Whether the user is authenticated with Firebase.
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    /// The Firebase Auth UID, if signed in.
    var firebaseUID: String? {
        currentUser?.uid
    }
    
    // MARK: - Sign In Anonymously
    
    /// Signs in anonymously with Firebase Auth.
    /// This gives us a Firebase UID that Firestore Security Rules can verify.
    /// Call this after a successful Spotify OAuth login.
    func signInAnonymously() async throws {
        // If already signed in, no need to sign in again
        if currentUser != nil { return }
        
        let result = try await Auth.auth().signInAnonymously()
        print("Firebase Auth: Signed in anonymously with UID: \(result.user.uid)")
    }
    
    // MARK: - Sign Out
    
    /// Signs out of Firebase Auth. Call this on logout.
    func signOut() {
        do {
            try Auth.auth().signOut()
            print("Firebase Auth: Signed out")
        } catch {
            print("Firebase Auth: Sign out error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Ensure Authenticated
    
    /// Ensures the user is authenticated. If not, signs in anonymously.
    /// Returns the Firebase UID.
    @discardableResult
    func ensureAuthenticated() async throws -> String {
        if let uid = currentUser?.uid {
            return uid
        }
        
        try await signInAnonymously()
        
        guard let uid = currentUser?.uid else {
            throw AuthError.signInFailed
        }
        
        return uid
    }
}

enum AuthError: LocalizedError {
    case signInFailed
    
    var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "Failed to authenticate. Please try again."
        }
    }
}
