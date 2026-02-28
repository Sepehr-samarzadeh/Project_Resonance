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
    @State private var showBlockConfirmation = false
    @State private var showReportSheet = false
    @State private var showUnmatchConfirmation = false
    @State private var isBlocking = false
    @State private var isUnmatching = false
    @Environment(\.dismiss) private var dismiss
    
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
                .onChange(of: chatManager.messages.count) {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showUnmatchConfirmation = true
                    } label: {
                        Label("Unmatch & Delete Chat", systemImage: "person.crop.circle.badge.minus")
                    }
                    
                    Button(role: .destructive) {
                        showBlockConfirmation = true
                    } label: {
                        Label("Block User", systemImage: "hand.raised.fill")
                    }
                    
                    Button {
                        showReportSheet = true
                    } label: {
                        Label("Report User", systemImage: "exclamationmark.triangle.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
        }
        .confirmationDialog(
            "Block \(otherUser?.name ?? "this user")?",
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                blockUser()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("They won't be able to message you or appear in your matches. This action cannot be undone.")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportUserView(
                reportedUserId: match.otherUserId(myId: currentUserId),
                reportedUserName: otherUser?.name ?? "User",
                currentUserId: currentUserId
            )
        }
        .confirmationDialog(
            "Unmatch \(otherUser?.name ?? "this user")?",
            isPresented: $showUnmatchConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unmatch & Delete Chat", role: .destructive) {
                unmatchUser()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the match and delete the entire conversation. This action cannot be undone.")
        }
        .overlay {
            if isBlocking || isUnmatching {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView().tint(.white)
                            Text(isUnmatching ? "Removing match..." : "Blocking user...")
                                .foregroundColor(.white)
                        }
                    }
            }
        }
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
        
        Task {
            let doc = try? await db.collection("users").document(otherUserId).getDocument()
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
        
        // Send push notification to the other user
        let otherId = match.otherUserId(myId: currentUserId)
        let myDoc = Firestore.firestore().collection("users").document(currentUserId)
        Task {
            let doc = try? await myDoc.getDocument()
            let myName = doc?.data()?["name"] as? String ?? "Someone"
            let preview = String(text.prefix(100))
            NotificationHelper.shared.sendNewMessageNotification(to: otherId, from: myName, messagePreview: preview)
        }
        
        chatManager.sendMessage(chatId: chatId, senderId: currentUserId, text: text) { success in
            if !success {
                
                messageText = text
            }
        }
    }
    
    private var db: Firestore {
        Firestore.firestore()
    }
    
    func blockUser() {
        isBlocking = true
        let blockedId = match.otherUserId(myId: currentUserId)
        
        Task {
            try? await BlockManager.shared.blockUser(blockerId: currentUserId, blockedId: blockedId)
            isBlocking = false
            dismiss()
        }
    }
    
    func unmatchUser() {
        isUnmatching = true
        
        Task {
            let _ = await MatchManager.shared.unmatch(match)
            isUnmatching = false
            dismiss()
        }
    }
}


// MARK: - Report User View
struct ReportUserView: View {
    let reportedUserId: String
    let reportedUserName: String
    let currentUserId: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = ""
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    
    private let reasons = [
        "Harassment or bullying",
        "Spam or fake profile",
        "Inappropriate content",
        "Impersonation",
        "Other"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Report \(reportedUserName)")
                        .font(.headline)
                    Text("Help us keep Resonance safe. Select a reason for your report.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Reason") {
                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                
                Section("Additional Details (optional)") {
                    TextField("Tell us more...", text: $additionalDetails, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button {
                        submitReport()
                    } label: {
                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Submit Report")
                                    .bold()
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(selectedReason.isEmpty ? Color.gray : Color.red)
                    .disabled(selectedReason.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thank you for helping keep Resonance safe. We'll review your report.")
            }
        }
    }
    
    func submitReport() {
        isSubmitting = true
        
        Task {
            try? await BlockManager.shared.reportUser(
                reporterId: currentUserId,
                reportedId: reportedUserId,
                reason: selectedReason,
                context: additionalDetails
            )
            isSubmitting = false
            showSuccess = true
        }
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

