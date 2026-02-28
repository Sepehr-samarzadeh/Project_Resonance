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
        NavigationView {
            Group {
                if matchManager.pendingMatches.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No pending matches")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        Text("When someone wants to match with you, they'll appear here")
                            .font(.caption)
                            .foregroundColor(.gray)
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
                
                // IMPORTANT: Start listening for matches when view appears
                if let userId = currentUserId {
                    print("PendingMatchesView appeared - starting match listener for user: \(userId)")
                    
                    // create a dummy listening object just to start the listener
                    // or call the listener directly without requiring current_listening
                    startMatchListener(userId: userId)
                }
            }
        }
    }
    
    //  start match listener independently
    func startMatchListener(userId: String) {
        let db = Firestore.firestore()
        
        // Listen for matches where Im user1
        db.collection("matches")
            .whereField("user1_id", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening for user1 matches: \(error)")
                    return
                }
                
                print("User1 matches: \(snapshot?.documents.count ?? 0)")
                matchManager.handleMatchesSnapshot(snapshot: snapshot, error: error, myUserId: userId)
            }
        
        // Listen for matches where Im user2
        db.collection("matches")
            .whereField("user2_id", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening for user2 matches: \(error)")
                    return
                }
                
                print("User2 matches: \(snapshot?.documents.count ?? 0)")
                matchManager.handleMatchesSnapshot(snapshot: snapshot, error: error, myUserId: userId)
            }
    }
}



struct PendingMatchCard: View {
    let match: Match
    let currentUserId: String
    
    @State private var otherUser: AppUser?
    @State private var isProcessing = false
    @State private var hasResponded = false //if user already responded
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                // NEW: Use ProfileImageView instead
                ProfileImageView(
                    imageUrl: otherUser?.imageUrl,
                    size: 60,
                    fallbackName: otherUser?.name ?? "User"
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(otherUser?.name ?? "Loading...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("wants to match with you!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            //add picture of the user
        
            // action Buttons
            VStack(spacing: 12) {
                Button {
                    print("ACCEPT BUTTON TAPPED")
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
                .buttonStyle(PlainButtonStyle()) // ADDED: Prevent gesture conflicts
                
                Button {
                    print("DECLINE BUTTON TAPPED")
                    declineMatch()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Decline")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .disabled(isProcessing || hasResponded)
                .buttonStyle(PlainButtonStyle()) // ADDED: Prevent gesture conflicts (might get buggy later check it later)
            }
        }
        .opacity(hasResponded ? 0.5 : 1.0) // fade out when responded
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
        .onAppear {
            loadOtherUser()
        }
    }
    
    
    
    func loadOtherUser() {
        let otherUserId = match.otherUserId(myId: currentUserId)
        
        let db = Firestore.firestore()
        db.collection("users").document(otherUserId).getDocument { doc, error in
            if let data = doc?.data(),
               let user = AppUser(document: data) {
                self.otherUser = user
            }
        }
    }
    
    func acceptMatch() {
        guard !hasResponded else { return }
        
        isProcessing = true
        hasResponded = true // mark as responded immediately
        
        MatchManager.shared.acceptMatch(match, myUserId: currentUserId) { success in
            isProcessing = false
            if success {
                print("Match accepted!")
            } else {
                hasResponded = false // reset on failure
            }
        }
    }
    
    func declineMatch() {
        guard !hasResponded else { return }
        
        isProcessing = true
        hasResponded = true // mark as responded immediately
        
        MatchManager.shared.declineMatch(match) { success in
            isProcessing = false
            if success {
                print("Match declined")
            } else {
                hasResponded = false // reset on failure
            }
        }
    }
}
    
    
    
   
    
    



struct ActiveMatchesView: View {
    @StateObject private var matchManager = MatchManager.shared
    @State private var currentUserId: String?
    
    var body: some View {
        NavigationView {
            Group {
                if matchManager.activeMatches.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No active chats")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        Text("Accept match requests to start chatting")
                            .font(.caption)
                            .foregroundColor(.gray)
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
        db.collection("users").document(otherUserId).getDocument { doc, error in
            if let data = doc?.data(),
               let user = AppUser(document: data) {
                self.otherUser = user
            }
        }
    }
}



