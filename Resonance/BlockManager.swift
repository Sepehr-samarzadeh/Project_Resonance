//
//  BlockManager.swift
//  Resonance
//
//  Created by Sepehr on 28/02/2026.
//

import Foundation
import FirebaseFirestore

@MainActor
class BlockManager: ObservableObject {
    static let shared = BlockManager()
    
    @Published var blockedUserIds: Set<String> = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Listen to Blocked Users
    
    func startListening(userId: String) {
        listener = db.collection("blocked_users")
            .whereField("blocker_id", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                self.blockedUserIds = Set(documents.compactMap { $0.data()["blocked_id"] as? String })
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        blockedUserIds = []
    }
    
    // MARK: - Block User
    
    func blockUser(blockerId: String, blockedId: String) async throws {
        let data: [String: Any] = [
            "blocker_id": blockerId,
            "blocked_id": blockedId,
            "created_at": Timestamp(date: Date())
        ]
        
        try await db.collection("blocked_users").addDocument(data: data)
        
        // Also delete any existing matches between these users
        await deleteMatchesBetween(user1: blockerId, user2: blockedId)
    }
    
    // MARK: - Report User (Apple Guideline 1.2)
    
    func reportUser(reporterId: String, reportedId: String, reason: String, context: String = "") async throws {
        let data: [String: Any] = [
            "reporter_id": reporterId,
            "reported_id": reportedId,
            "reason": reason,
            "context": context,
            "created_at": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        try await db.collection("reports").addDocument(data: data)
    }
    
    // MARK: - Check if Blocked
    
    func isBlocked(_ userId: String) -> Bool {
        return blockedUserIds.contains(userId)
    }
    
    // MARK: - Unblock User
    
    func unblockUser(blockerId: String, blockedId: String) async throws {
        let snapshot = try await db.collection("blocked_users")
            .whereField("blocker_id", isEqualTo: blockerId)
            .whereField("blocked_id", isEqualTo: blockedId)
            .getDocuments()
        
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }
    
    // MARK: - Helpers
    
    private func deleteMatchesBetween(user1: String, user2: String) async {
        // Matches where user1 is user1_id
        if let snapshot = try? await db.collection("matches")
            .whereField("user1_id", isEqualTo: user1)
            .whereField("user2_id", isEqualTo: user2)
            .getDocuments() {
            for doc in snapshot.documents {
                // Also delete associated chat
                if let chatId = doc.data()["chat_id"] as? String {
                    try? await db.collection("chats").document(chatId).delete()
                }
                try? await doc.reference.delete()
            }
        }
        
        // Matches where user1 is user2_id (reversed)
        if let snapshot = try? await db.collection("matches")
            .whereField("user1_id", isEqualTo: user2)
            .whereField("user2_id", isEqualTo: user1)
            .getDocuments() {
            for doc in snapshot.documents {
                if let chatId = doc.data()["chat_id"] as? String {
                    try? await db.collection("chats").document(chatId).delete()
                }
                try? await doc.reference.delete()
            }
        }
    }
}
