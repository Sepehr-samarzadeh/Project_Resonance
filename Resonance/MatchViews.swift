//
//  MatchViews.swift
//  Resonance
//
//  Created by Sepehr on 15/12/2025.
//

import SwiftUI
import FirebaseFirestore


struct PendingMatchesView: View {
    @StateObject private var matchManager = MatchManager.shared
    @State private var currentUserId: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if matchManager.pendingMatches.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        
                        Text("No pending matches")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("When someone wants to match with you, they'll appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(matchManager.pendingMatches) { match in
                            PendingMatchCard(match: match, currentUserId: currentUserId ?? "")
                        }
                    }
                }
            }
            .navigationTitle("Match Requests")
            .onAppear {
                currentUserId = UserManager.shared.getCurrentUserId()
                // MatchManager handles listeners centrally — no duplicate setup needed
                if let userId = currentUserId {
                    matchManager.startMatchListeners(userId: userId)
                }
            }
        }
    }
}



struct PendingMatchCard: View {
    let match: Match
    let currentUserId: String
    
    @State private var otherUser: AppUser?
    @State private var isProcessing = false
    @State private var hasResponded = false
    @State private var showDeclineConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                ProfileImageView(
                    imageUrl: otherUser?.imageUrl,
                    size: 60,
                    fallbackName: otherUser?.name ?? "User"
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(otherUser?.name ?? "Loading...")
                        .font(.headline)
                    
                    Text("wants to match with you!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button {
                    acceptMatch()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .disabled(isProcessing || hasResponded)
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Accept match with \(otherUser?.name ?? "user")")
                
                Button {
                    showDeclineConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Decline")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .disabled(isProcessing || hasResponded)
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Decline match with \(otherUser?.name ?? "user")")
            }
        }
        .opacity(hasResponded ? 0.5 : 1.0)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            loadOtherUser()
        }
        .confirmationDialog(
            "Decline match with \(otherUser?.name ?? "this user")?",
            isPresented: $showDeclineConfirmation,
            titleVisibility: .visible
        ) {
            Button("Decline", role: .destructive) {
                declineMatch()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    
    
    func loadOtherUser() {
        let otherUserId = match.otherUserId(myId: currentUserId)
        
        let db = Firestore.firestore()
        Task {
            let doc = try? await db.collection("users").document(otherUserId).getDocument()
            if let data = doc?.data(),
               let user = AppUser(document: data) {
                self.otherUser = user
            }
        }
    }
    
    func acceptMatch() {
        guard !hasResponded else { return }
        
        isProcessing = true
        hasResponded = true
        
        Task {
            let success = await MatchManager.shared.acceptMatch(match, myUserId: currentUserId)
            isProcessing = false
            if !success {
                hasResponded = false
            }
        }
    }
    
    func declineMatch() {
        guard !hasResponded else { return }
        
        isProcessing = true
        hasResponded = true
        
        Task {
            let success = await MatchManager.shared.declineMatch(match)
            isProcessing = false
            if !success {
                hasResponded = false
            }
        }
    }
}
    
    
    
   
    
    



struct ActiveMatchesView: View {
    @StateObject private var matchManager = MatchManager.shared
    @State private var currentUserId: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if matchManager.activeMatches.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        
                        Text("No active chats")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("Accept match requests to start chatting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(matchManager.activeMatches) { match in
                            if let chatId = match.chatId {
                                NavigationLink {
                                    ChatView(chatId: chatId, match: match, currentUserId: currentUserId ?? "")
                                } label: {
                                    ActiveMatchRow(match: match, currentUserId: currentUserId ?? "")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .onAppear {
                currentUserId = UserManager.shared.getCurrentUserId()
            }
        }
    }
}


struct ActiveMatchRow: View {
    let match: Match
    let currentUserId: String
    
    @State private var otherUser: AppUser?
    
    var body: some View {
        HStack(spacing: 12) {
            // profile Image
            if let imageUrl = otherUser?.imageUrl,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(Color.gray)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(otherUser?.name ?? "Loading...")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.caption)
                    Text(match.trackName)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .onAppear {
            loadOtherUser()
        }
    }
    
    func loadOtherUser() {
        let otherUserId = match.otherUserId(myId: currentUserId)
        
        let db = Firestore.firestore()
        Task {
            let doc = try? await db.collection("users").document(otherUserId).getDocument()
            if let data = doc?.data(),
               let user = AppUser(document: data) {
                self.otherUser = user
            }
        }
    }
}



