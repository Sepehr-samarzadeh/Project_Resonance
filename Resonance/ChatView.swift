//
//  ChatView.swift
//  Resonance
//
//  Created by Sepehr on 17/12/2025.
//
import SwiftUI
import FirebaseFirestore

struct ChatView: View {
    let chatId: String
    let match: Match
    let currentUserId: String
    
    @StateObject private var chatManager = ChatManager()
    @State private var messageText = ""
    @State private var otherUser: AppUser?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        
                        matchInfoHeader()
                            .padding()
                        
                        // messages
                        ForEach(chatManager.messages) { message in
                            MessageBubble(
                                message: message,
                                isCurrentUser: message.senderId == currentUserId,
                                otherUserName: otherUser?.name ?? "User"
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: chatManager.messages.count) { _ in
                    
                    if let lastMessage = chatManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            
            messageInputBar()
        }
        .navigationTitle(otherUser?.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadOtherUser()
            chatManager.startListening(chatId: chatId)
        }
        .onDisappear {
            chatManager.stopListening()
        }
    }
    
    
    func matchInfoHeader() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 30))
                .foregroundColor(.green)
            
            Text("You matched on")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(match.trackName)
                .font(.subheadline)
                .bold()
            
            Text("by \(match.artistName)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Divider()
                .padding(.top, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    
    func messageInputBar() -> some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .lineLimit(1...4)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty ? .gray : .green)
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 3, y: -2)
    }
    
    
    func loadOtherUser() {
        let otherUserId = match.otherUserId(myId: currentUserId)
        
        db.collection("users").document(otherUserId).getDocument { doc, error in
            if let data = doc?.data(),
               let user = AppUser(document: data) {
                self.otherUser = user
            }
        }
    }
    
    
    func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
    
        messageText = ""
        
        chatManager.sendMessage(chatId: chatId, senderId: currentUserId, text: text) { success in
            if !success {
                
                messageText = text
            }
        }
    }
    
    private var db: Firestore {
        Firestore.firestore()
    }
}


struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let otherUserName: String
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                
                if !isCurrentUser {
                    Text(otherUserName)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.leading, 12)
                }
                
                 
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? Color.green : Color.gray.opacity(0.2))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(20)
                
                Text(formatTime(message.sentAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
            }
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: date)
    }
}

struct EmptyChatView: View {
    let otherUserName: String
    let trackName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Say hi to \(otherUserName)!")
                .font(.title3)
                .bold()
            
            Text("You both love \(trackName)")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

