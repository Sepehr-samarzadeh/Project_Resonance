//
//  ChatManager.swift
//  Resonance
//
//  Created by Sepehr on 17/12/2025.
//

import SwiftUI
import FirebaseFirestore

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var messagesListener: ListenerRegistration?
    
    func startListening(chatId: String) {
        messagesListener = db.collection("messages")
            .whereField("chat_id", isEqualTo: chatId)
            .order(by: "sent_at", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                let fetchedMessages = documents.compactMap { doc -> Message? in
                    do {
                        var message = try doc.data(as: Message.self)
                        message.id = doc.documentID
                        return message
                    } catch {
                        return nil
                    }
                }
                
                self.messages = fetchedMessages
            }
    }
    
    func stopListening() {
        messagesListener?.remove()
        messages = []
    }
    
    func sendMessage(chatId: String, senderId: String, text: String, completion: @escaping (Bool) -> Void) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(false)
            return
        }
        
        let message = Message(chatId: chatId, senderId: senderId, text: text)
        
        do {
            try db.collection("messages").addDocument(from: message) { [weak self] error in
                if error != nil {
                    completion(false)
                } else {
                    self?.updateChatTimestamp(chatId: chatId)
                    completion(true)
                }
            }
        } catch {
            completion(false)
        }
    }
    
    private func updateChatTimestamp(chatId: String) {
        db.collection("chats").document(chatId).updateData([
            "last_message_at": Timestamp(date: Date())
        ])
    }
}
