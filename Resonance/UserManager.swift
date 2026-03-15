//
//  UserManager.swift
//  Resonance
//
//  Created by Sepehr on 14/12/2025.
//
import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class UserManager {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func registerUser(spotifyUser: SpotifyUser) async -> Bool {
        let appUser = AppUser(from: spotifyUser)
        var data = appUser.toDictionary()
        
        // Store the Firebase Auth UID in the user document for security rule validation
        if let firebaseUID = AuthManager.shared.firebaseUID {
            data["firebase_uid"] = firebaseUID
            print("[REGISTER] Firebase UID: \(firebaseUID)")
        } else {
            print("[REGISTER] WARNING: No Firebase UID available")
        }
        
        print("[REGISTER] Writing user doc for id: \(appUser.id)")
        do {
            try await db.collection("users").document(appUser.id).setData(data, merge: true)
            UserDefaults.standard.set(appUser.id, forKey: "current_user_id")
            print("[REGISTER] SUCCESS - current_user_id set to: \(appUser.id)")
            return true
        } catch {
            print("[REGISTER] FAILED - Firestore error: \(error)")
            return false
        }
    }
    
    func getCurrentUserId() -> String? {
        return UserDefaults.standard.string(forKey: "current_user_id")
    }
    
    func updateOnlineStatus(userId: String, isOnline: Bool) {
        // Respect "Show Online Status" privacy setting (defaults to true)
        let showOnline = UserDefaults.standard.object(forKey: "privacy_show_online") as? Bool ?? true
        guard showOnline else {
            // User opted out — remove any stale online status
            db.collection("users").document(userId).updateData([
                "is_online": false,
                "last_active": FieldValue.delete()
            ])
            return
        }
        db.collection("users").document(userId).updateData([
            "is_online": isOnline,
            "last_active": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Profile Editing
    
    func updateProfile(userId: String, bio: String?, favoriteGenres: [String]?) async throws {
        var updates: [String: Any] = [:]
        if let bio = bio { updates["bio"] = bio }
        if let genres = favoriteGenres { updates["favorite_genres"] = genres }
        
        guard !updates.isEmpty else { return }
        try await db.collection("users").document(userId).updateData(updates)
    }
    
    func updateTopArtists(userId: String, artistIds: [String], artistNames: [String]) async throws {
        try await db.collection("users").document(userId).updateData([
            "top_artist_ids": artistIds,
            "top_artist_names": artistNames
        ])
    }
    
    // MARK: - FCM Token
    
    func updateFCMToken(userId: String, token: String) {
        db.collection("users").document(userId).updateData([
            "fcm_token": token
        ])
    }
    
    // MARK: - Account Deletion (Apple Requirement 5.1.1v)
    
    func deleteAccount(userId: String) async throws {
        let batch = db.batch()
        
        // 1. Delete user document
        let userRef = db.collection("users").document(userId)
        batch.deleteDocument(userRef)
        
        // 2. Delete current_listening document
        let listeningRef = db.collection("current_listening").document(userId)
        batch.deleteDocument(listeningRef)
        
        // Commit batch for user data
        try await batch.commit()
        
        // 3. Delete matches where user is involved
        await deleteUserMatches(userId: userId)
        
        // 4. Delete messages sent by user
        await deleteUserMessages(userId: userId)
        
        // 5. Clear local data and sign out
        clearLocalData()
        NowPlayingManager.shared.stopTracking()
    }
    
    private func deleteUserMatches(userId: String) async {
        // Helper: delete a match and its associated chat + messages (mirrors unmatch() logic)
        func deleteMatchAndChat(_ doc: DocumentSnapshot) async {
            let data = doc.data() ?? [:]
            
            // Delete the associated chat and its messages, if any
            if let chatId = data["chat_id"] as? String {
                if let messages = try? await db.collection("messages")
                    .whereField("chat_id", isEqualTo: chatId)
                    .getDocuments() {
                    let batch = db.batch()
                    for msgDoc in messages.documents {
                        batch.deleteDocument(msgDoc.reference)
                    }
                    batch.deleteDocument(db.collection("chats").document(chatId))
                    try? await batch.commit()
                }
            }
            
            // Delete the match document itself
            try? await doc.reference.delete()
        }
        
        // Matches as user1
        if let snapshot = try? await db.collection("matches")
            .whereField("user1_id", isEqualTo: userId)
            .getDocuments() {
            for doc in snapshot.documents {
                await deleteMatchAndChat(doc)
            }
        }
        
        // Matches as user2
        if let snapshot = try? await db.collection("matches")
            .whereField("user2_id", isEqualTo: userId)
            .getDocuments() {
            for doc in snapshot.documents {
                await deleteMatchAndChat(doc)
            }
        }
    }
    
    private func deleteUserMessages(userId: String) async {
        if let snapshot = try? await db.collection("messages")
            .whereField("sender_id", isEqualTo: userId)
            .getDocuments() {
            for doc in snapshot.documents {
                try? await doc.reference.delete()
            }
        }
    }
    
    func clearLocalData() {
        // Clear Keychain (tokens)
        KeychainHelper.deleteAll()
        
        // Clear non-sensitive UserDefaults
        UserDefaults.standard.removeObject(forKey: "current_user_id")
        
        // Sign out of Firebase Auth
        AuthManager.shared.signOut()
    }
}





