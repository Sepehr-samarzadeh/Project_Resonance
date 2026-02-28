//
//  UserManager.swift
//  Resonance
//
//  Created by Sepehr on 14/12/2025.
//
import Foundation
import FirebaseFirestore

@MainActor
class UserManager {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func registerUser(spotifyUser: SpotifyUser, completion: @escaping (Bool) -> Void) {
        let appUser = AppUser(from: spotifyUser)
        let data = appUser.toDictionary()
        
        db.collection("users").document(appUser.id).setData(data, merge: true) { error in
            if let error = error {
                print("Error registering user: \(error)")
                completion(false)
            } else {
                UserDefaults.standard.set(appUser.id, forKey: "current_user_id")
                completion(true)
            }
        }
    }
    
    func getCurrentUserId() -> String? {
        return UserDefaults.standard.string(forKey: "current_user_id")
    }
    
    func updateOnlineStatus(userId: String, isOnline: Bool) {
        db.collection("users").document(userId).updateData([
            "is_online": isOnline,
            "last_active": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Account Deletion (Apple Requirement 5.1.1v)
    
    func deleteAccount(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        
        // 1. Delete user document
        let userRef = db.collection("users").document(userId)
        batch.deleteDocument(userRef)
        
        // 2. Delete current_listening document
        let listeningRef = db.collection("current_listening").document(userId)
        batch.deleteDocument(listeningRef)
        
        // Commit batch for user data
        batch.commit { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let self = self else { return }
            
            // 3. Delete matches where user is involved
            self.deleteUserMatches(userId: userId) {
                // 4. Delete messages sent by user
                self.deleteUserMessages(userId: userId) {
                    // 5. Clear local data
                    self.clearLocalData()
                    NowPlayingManager.shared.stopTracking()
                    
                    completion(.success(()))
                }
            }
        }
    }
    
    private func deleteUserMatches(userId: String, completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        // Matches as user1
        group.enter()
        db.collection("matches")
            .whereField("user1_id", isEqualTo: userId)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { doc in
                    doc.reference.delete()
                }
                group.leave()
            }
        
        // Matches as user2
        group.enter()
        db.collection("matches")
            .whereField("user2_id", isEqualTo: userId)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { doc in
                    doc.reference.delete()
                }
                group.leave()
            }
        
        group.notify(queue: .main) {
            completion()
        }
    }
    
    private func deleteUserMessages(userId: String, completion: @escaping () -> Void) {
        db.collection("messages")
            .whereField("sender_id", isEqualTo: userId)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { doc in
                    doc.reference.delete()
                }
                completion()
            }
    }
    
    func clearLocalData() {
        UserDefaults.standard.removeObject(forKey: "spotify_access_token")
        UserDefaults.standard.removeObject(forKey: "spotify_refresh_token")
        UserDefaults.standard.removeObject(forKey: "current_user_id")
        UserDefaults.standard.removeObject(forKey: "code_verifier")
    }
}





