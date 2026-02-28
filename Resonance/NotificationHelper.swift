//
//  NotificationHelper.swift
//  Resonance
//
//  Writes notification records to Firestore. A server-side Cloud Function
//  should watch the "notifications" collection and use FCM to deliver
//  push notifications to the recipient's device.
//
//  To deploy the Cloud Function, create a Firebase Cloud Function that:
//  1. Triggers on document creation in "notifications" collection
//  2. Reads the recipient's FCM token from the "users" collection
//  3. Sends a push notification via Firebase Admin SDK
//

import Foundation
import FirebaseFirestore

@MainActor
class NotificationHelper {
    static let shared = NotificationHelper()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Notify a user about a new match request
    func sendMatchRequestNotification(to recipientId: String, from senderName: String) {
        writeNotification(
            recipientId: recipientId,
            title: "New Match Request!",
            body: "\(senderName) wants to connect with you",
            type: "match_request"
        )
    }
    
    /// Notify a user that their match was accepted
    func sendMatchAcceptedNotification(to recipientId: String, from senderName: String) {
        writeNotification(
            recipientId: recipientId,
            title: "Match Accepted! 🎉",
            body: "You and \(senderName) are now connected",
            type: "match_accepted"
        )
    }
    
    /// Notify a user about a new chat message
    func sendNewMessageNotification(to recipientId: String, from senderName: String, messagePreview: String) {
        writeNotification(
            recipientId: recipientId,
            title: senderName,
            body: messagePreview,
            type: "new_message"
        )
    }
    
    private func writeNotification(recipientId: String, title: String, body: String, type: String) {
        let data: [String: Any] = [
            "recipient_id": recipientId,
            "title": title,
            "body": body,
            "type": type,
            "is_read": false,
            "created_at": Timestamp(date: Date())
        ]
        
        db.collection("notifications").addDocument(data: data) { error in
            if let error = error {
                print("Failed to write notification: \(error.localizedDescription)")
            }
        }
    }
}
