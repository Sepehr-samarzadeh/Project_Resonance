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
                print("User registered: \(appUser.name)")
                
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
        ]) { error in
            if let error = error {
                print("Error updating status: \(error)")
            } else {
                print("Updated online status: \(isOnline)")
            }
        }
    }
}





