//
//  MatchManager.swift
//  Resonance
//
//  Created by Sepehr on 15/12/2025.
//

import Foundation
import FirebaseFirestore
import SwiftUI


@MainActor
class MatchManager: ObservableObject {
    static let shared = MatchManager()
    
    @Published var potentialMatches: [PotentialMatch] = []
    @Published var pendingMatches: [Match] = []
    @Published var activeMatches: [Match] = []
    
    private let db = Firestore.firestore()
    private var listenersSnapshot: ListenerRegistration?
    private var matchUser1Listener: ListenerRegistration?
    private var matchUser2Listener: ListenerRegistration?
    private var matchListenersActive = false
    
    private init() {}
    
    func startListening(currentUserId: String, currentListening: CurrentListening?) {
        guard let listening = currentListening else { return }
        
        listenersSnapshot = db.collection("current_listening")
            .whereField("is_playing", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                var matches: [PotentialMatch] = []
                
                for doc in documents {
                    let data = doc.data()
                    let userId = doc.documentID
                    
                    if userId == currentUserId { continue }
                    
                    let trackId = data["track_id"] as? String ?? ""
                    let artistId = data["artist_id"] as? String ?? ""
                    
                    if trackId == listening.trackId && !trackId.isEmpty {
                        if let otherListening = CurrentListening(userId: userId, document: data) {
                            matches.append(PotentialMatch(
                                userId: userId,
                                listening: otherListening,
                                matchType: .sameTrack
                            ))
                        }
                    } else if artistId == listening.artistId && !artistId.isEmpty {
                        if let otherListening = CurrentListening(userId: userId, document: data) {
                            matches.append(PotentialMatch(
                                userId: userId,
                                listening: otherListening,
                                matchType: .sameArtist
                            ))
                        }
                    }
                }
                
                self.potentialMatches = matches
            }
        
        startMatchListeners(userId: currentUserId)
    }
    
    func stopListening() {
        listenersSnapshot?.remove()
        matchUser1Listener?.remove()
        matchUser2Listener?.remove()
        listenersSnapshot = nil
        matchUser1Listener = nil
        matchUser2Listener = nil
        matchListenersActive = false
        potentialMatches = []
    }
    
    // MARK: - Centralized Match Listeners (called once, not per-view)
    
    func startMatchListeners(userId: String) {
        guard !matchListenersActive else { return }
        matchListenersActive = true
        
        matchUser1Listener = db.collection("matches")
            .whereField("user1_id", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleMatchesSnapshot(snapshot: snapshot, error: error, myUserId: userId)
            }
        
        matchUser2Listener = db.collection("matches")
            .whereField("user2_id", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleMatchesSnapshot(snapshot: snapshot, error: error, myUserId: userId)
            }
    }
    
    private func handleMatchesSnapshot(snapshot: QuerySnapshot?, error: Error?, myUserId: String) {
        guard let documents = snapshot?.documents else { return }
        
        var pending: [Match] = []
        var active: [Match] = []
        
        for doc in documents {
            do {
                var match = try doc.data(as: Match.self)
                match.id = doc.documentID
                
                let amUser1 = match.user1Id == myUserId
                let myStatus = amUser1 ? match.user1Accepted : match.user2Accepted
                let otherStatus = amUser1 ? match.user2Accepted : match.user1Accepted
                
                if amUser1 {
                    if myStatus && otherStatus {
                        active.append(match)
                    }
                } else {
                    if !myStatus {
                        pending.append(match)
                    } else if myStatus && otherStatus {
                        active.append(match)
                    }
                }
            } catch {
                // Skip malformed documents
            }
        }
        
        self.pendingMatches = pending
        self.activeMatches = active
    }
    
    func createMatch(currentUserId: String, otherUserId: String, listening: CurrentListening, completion: @escaping (Bool) -> Void) {
        db.collection("matches")
            .whereField("user1_id", in: [currentUserId, otherUserId])
            .whereField("user2_id", in: [currentUserId, otherUserId])
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if snapshot?.documents.first != nil {
                    completion(false)
                    return
                }
                
                let match = Match(user1Id: currentUserId, user2Id: otherUserId, listening: listening)
                
                do {
                    try self.db.collection("matches").addDocument(from: match) { error in
                        completion(error == nil)
                    }
                } catch {
                    completion(false)
                }
            }
    }
    

    
    
    func acceptMatch(_ match: Match, myUserId: String, completion: @escaping (Bool) -> Void) {
        guard let matchId = match.id else {
            completion(false)
            return
        }
        
        let field = match.user1Id == myUserId ? "user1_accepted" : "user2_accepted"
        
        db.collection("matches").document(matchId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            guard document?.exists == true else {
                completion(false)
                return
            }
            
            self.db.collection("matches").document(matchId).updateData([
                field: true
            ]) { error in
                if error != nil {
                    completion(false)
                    return
                }
                
                var updatedMatch = match
                if match.user1Id == myUserId {
                    updatedMatch.user1Accepted = true
                } else {
                    updatedMatch.user2Accepted = true
                }
                
                if updatedMatch.isBothAccepted {
                    self.createChat(for: updatedMatch)
                }
                
                completion(true)
            }
        }
    }
    
    
    func declineMatch(_ match: Match, completion: @escaping (Bool) -> Void) {
        guard let matchId = match.id else {
            completion(false)
            return
        }
        
        db.collection("matches").document(matchId).getDocument { [weak self] document, error in
            guard document?.exists == true else {
                completion(true)
                return
            }
            
            self?.db.collection("matches").document(matchId).delete { error in
                completion(error == nil)
            }
        }
    }
    
    private func createChat(for match: Match) {
        guard let matchId = match.id else { return }
        
        let chat = Chat(matchId: matchId, user1Id: match.user1Id, user2Id: match.user2Id)
        
        do {
            let chatRef = try db.collection("chats").addDocument(from: chat) { _ in }
            
            db.collection("matches").document(matchId).updateData([
                "chat_id": chatRef.documentID
            ])
        } catch {
            // Chat creation failed silently
        }
    }
}

struct PotentialMatch: Identifiable {
    let id = UUID()
    let userId: String
    let listening: CurrentListening
    let matchType: MatchType
    
    enum MatchType {
        case sameTrack
        case sameArtist
    }
}


struct DiscoveryView: View {
    @StateObject private var matchManager = MatchManager.shared
    @StateObject private var nowPlayingManager = NowPlayingManager.shared
    @State private var currentUserId: String?
    @State private var selectedMatch: PotentialMatch?
    @State private var showMatchPrompt = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Current Listening Section
                if let listening = nowPlayingManager.currentListening {
                    currentListeningCard(listening)
                } else {
                    Text("Start playing music to find matches!")
                        .foregroundColor(.gray)
                        .padding()
                }
                
                Divider()
                
                // Potential Matches
                if matchManager.potentialMatches.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No one listening to similar music right now")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(matchManager.potentialMatches) { match in
                        PotentialMatchRow(match: match)
                            .onTapGesture {
                                selectedMatch = match
                                showMatchPrompt = true
                            }
                    }
                }
            }
            .navigationTitle("Discover")
            .sheet(isPresented: $showMatchPrompt) {
                if let match = selectedMatch,
                   let userId = currentUserId,
                   let listening = nowPlayingManager.currentListening {
                    MatchPromptView(
                        match: match,
                        currentUserId: userId,
                        currentListening: listening
                    )
                }
            }
            .onAppear {
                startDiscovery()
            }
            .onDisappear {
                matchManager.stopListening()
            }
        }
    }
    
    func startDiscovery() {
        currentUserId = UserManager.shared.getCurrentUserId()
        
        guard let userId = currentUserId,
              let listening = nowPlayingManager.currentListening else {
            return
        }
        
        matchManager.startListening(currentUserId: userId, currentListening: listening)
    }
    
    func currentListeningCard(_ listening: CurrentListening) -> some View {
        HStack(spacing: 12) {
            if let imageUrl = listening.imageUrl,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    Rectangle().fill(Color.gray)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("You're listening to")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(listening.trackName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(listening.artistName)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}


struct PotentialMatchRow: View {
    let match: PotentialMatch
    @State private var user: AppUser?
    
    var body: some View {
        HStack(spacing: 12) {
            // Replace AsyncImage with ProfileImageView
            ProfileImageView(
                imageUrl: user?.imageUrl,
                size: 50,
                fallbackName: user?.name
            )
            
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user?.name ?? "Loading...")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Image(systemName: match.matchType == .sameTrack ? "music.note" : "person.wave.2")
                        .font(.caption)
                    
                    if match.matchType == .sameTrack {
                        Text("Same song: \(match.listening.trackName)")
                    } else {
                        Text("Same artist: \(match.listening.artistName)")
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
        .onAppear {
            loadUser()
            

        }
    }
    
    func loadUser() {
        let db = Firestore.firestore()
        db.collection("users").document(match.userId).getDocument { doc, error in
            if let data = doc?.data(),
               let user = AppUser(document: data) {
                self.user = user
            }
        }
   }
    


}


struct MatchPromptView: View {
    @Environment(\.dismiss) var dismiss
    let match: PotentialMatch
    let currentUserId: String
    let currentListening: CurrentListening
    
    @State private var user: AppUser?
    @State private var isCreatingMatch = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Match Icon
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            // User Info
            if let user = user {
                if let imageUrl = user.imageUrl,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(Color.gray)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                }
                
                Text(user.name)
                    .font(.title)
                    .bold()
            }
            
            // Match Info
            VStack(spacing: 8) {
                if match.matchType == .sameTrack {
                    Text("You're both listening to")
                        .foregroundColor(.gray)
                    Text(match.listening.trackName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("by \(match.listening.artistName)")
                        .foregroundColor(.gray)
                } else {
                    Text("You're both listening to")
                        .foregroundColor(.gray)
                    Text(match.listening.artistName)
                        .font(.headline)
                }
            }
            .padding()
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 20) {
                Button {
                    dismiss()
                } label: {
                    Text("Not Now")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                Button {
                    sendMatchRequest()
                } label: {
                    if isCreatingMatch {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Say Hi!")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .disabled(isCreatingMatch)
            }
            .padding()
        }
        .padding()
        .onAppear {
            loadUser()
        }
    }
    
    func loadUser() {
        let db = Firestore.firestore()
        db.collection("users").document(match.userId).getDocument { doc, error in
            if let data = doc?.data(),
               let user = AppUser(document: data) {
                self.user = user
            }
        }
    }
    
    func sendMatchRequest() {
        isCreatingMatch = true
        
        MatchManager.shared.createMatch(
            currentUserId: currentUserId,
            otherUserId: match.userId,
            listening: currentListening
        ) { success in
            isCreatingMatch = false
            dismiss()
        }
    }
}
