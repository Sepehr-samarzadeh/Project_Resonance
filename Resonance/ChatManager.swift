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
    
    // MARK: - Start Listening to Messages
    func startListening(chatId: String) {
        print("Started listening to chat: \(chatId)")
        
        messagesListener = db.collection("messages")
            .whereField("chat_id", isEqualTo: chatId)
            .order(by: "sent_at", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to messages: \(error)")
                    return
                }
                
                print("Messages snapshot received")
                print("Documents: \(snapshot?.documents.count ?? 0)")
                
                guard let documents = snapshot?.documents else {
                    print("No documents")
                    return
                }
                
                // Debug: Print all documents
                for (index, doc) in documents.enumerated() {
                    print("   Message \(index): \(doc.data())")
                }
                
                let fetchedMessages = documents.compactMap { doc -> Message? in
                    do {
                        var message = try doc.data(as: Message.self)
                        message.id = doc.documentID
                        print("   Decoded message: \(message.text)")
                        return message
                    } catch {
                        print("   Failed to decode message: \(error)")
                        return nil
                    }
                }
                
                DispatchQueue.main.async {
                    self.messages = fetchedMessages
                    print("Updated UI with \(fetchedMessages.count) messages")
                }
            }
    }
    func stopListening() {
        messagesListener?.remove()
        messages = []
        print("Stopped listening to messages")
    }
    
    
    func sendMessage(chatId: String, senderId: String, text: String, completion: @escaping (Bool) -> Void) {
        print("SENDING MESSAGE")
        print("   Chat ID: \(chatId)")
        print("   Sender ID: \(senderId)")
        print("   Text: \(text)")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(false)
            return
        }
        
        let message = Message(chatId: chatId, senderId: senderId, text: text)
        
        do {
            try db.collection("messages").addDocument(from: message) { [weak self] error in
                if let error = error {
                    print("Error sending message: \(error)")
                    completion(false)
                } else {
                    print("Message sent!")
                    
                    // update chats last_message_at
                    self?.updateChatTimestamp(chatId: chatId)
                    
                    completion(true)
                }
            }
        } catch {
            print("Error encoding message: \(error)")
            completion(false)
        }
    }
    
    
    private func updateChatTimestamp(chatId: String) {
        db.collection("chats").document(chatId).updateData([
            "last_message_at": Timestamp(date: Date())
        ])
    }
}
