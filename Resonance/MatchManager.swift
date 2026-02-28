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
    private var matchesSnapshot: ListenerRegistration?
    
    private init() {}
    
    func startListening(currentUserId: String, currentListening: CurrentListening?) {
        guard let listening = currentListening else {
            print("not listening to anything")
            return
        }
        
        print("started looking for matches...")
        
        listenersSnapshot = db.collection("current_listening")
            .whereField("is_playing", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("error listening for matches: \(error)")
                    return
                }
                
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
                    }
                  
                    else if artistId == listening.artistId && !artistId.isEmpty {
                        if let otherListening = CurrentListening(userId: userId, document: data) {
                            matches.append(PotentialMatch(
                                userId: userId,
                                listening: otherListening,
                                matchType: .sameArtist
                            ))
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.potentialMatches = matches
                    print("Found \(matches.count) potential matches")
                }
            }
        
        listenMyMatches(userId: currentUserId)
    }
    
   
    func stopListening() {
        listenersSnapshot?.remove()
        matchesSnapshot?.remove()
        potentialMatches = []
        print("Stopped looking for matches")
    }
    

    
    private func listenMyMatches(userId: String) {
        print("Setting up match listeners for user: \(userId)")
        
        // Listen for matches where Im user1
        db.collection("matches")
            .whereField("user1_id", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                print("User1 matches callback - Documents: \(snapshot?.documents.count ?? 0)")
                
                if let docs = snapshot?.documents {
                    for doc in docs {
                        print("Match doc: \(doc.documentID) - \(doc.data())")
                    }
                }
                
                self?.handleMatchesSnapshot(snapshot: snapshot, error: error, myUserId: userId)
            }
        
        // Listen for matches where Im user2
        db.collection("matches")
            .whereField("user2_id", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                print("User2 matches callback - Documents: \(snapshot?.documents.count ?? 0)")
                
                if let docs = snapshot?.documents {
                    for doc in docs {
                        print(" Match doc: \(doc.documentID) - \(doc.data())")
                    }
                }
                
                self?.handleMatchesSnapshot(snapshot: snapshot, error: error, myUserId: userId)
            }
    }
    
    
    
    func handleMatchesSnapshot(snapshot: QuerySnapshot?, error: Error?, myUserId: String) {
        if let error = error {
            print("Error listening for matches: \(error)")
            return
        }
        
        guard let documents = snapshot?.documents else { return }
        
        print("Processing \(documents.count) match documents")
        
        var pending: [Match] = []
        var active: [Match] = []
        
        for doc in documents {
            do {
                var match = try doc.data(as: Match.self)
                match.id = doc.documentID
                
                print("Match: user1=\(match.user1Id), user2=\(match.user2Id)")
                print("Status: user1_accepted=\(match.user1Accepted), user2_accepted=\(match.user2Accepted)")
                
                // Am I user1 or user2?
                let amUser1 = match.user1Id == myUserId
                let myStatus = amUser1 ? match.user1Accepted : match.user2Accepted
                let otherStatus = amUser1 ? match.user2Accepted : match.user1Accepted
                
                // IMPORTANT: Only show in pending if OTHER person initiated and I havent responded
                // User1 initiates, so user2 sees it as pending
                // User1 should NOT see their own match request as pending
                
                if amUser1 {
                    // Im user1 (I sent the request)
                    if myStatus && otherStatus {
                        // Both accepted - show in active
                        active.append(match)
                        print("  Added to ACTIVE (both accepted)")
                    } else {
                        // Waiting for user2 to respond - dont show anywhere yet
                        print("  WAITING for user2 to accept (I initiated)")
                    }
                } else {
                    // Im user2 (I received the request)
                    if !myStatus {
                        // I havent accepted yet - show in pending
                        pending.append(match)
                        print("  Added to PENDING (I need to respond)")
                    } else if myStatus && otherStatus {
                        // Both accepted - show in active
                        active.append(match)
                        print("   Added to ACTIVE (both accepted)")
                    } else {
                        // i accepted, waiting for user1 (shouldnt happen since user1 autoaccepts)
                        print("  WAITING (I accepted, waiting for user1)")
                    }
                }
                
            } catch {
                print("Error decoding match: \(error)")
            }
        }
        
        DispatchQueue.main.async {
            self.pendingMatches = pending
            self.activeMatches = active
            print("Updated: \(pending.count) pending, \(active.count) active")
        }
    }
    
    func createMatch(currentUserId: String, otherUserId: String, listening: CurrentListening, completion: @escaping (Bool) -> Void) {
        db.collection("matches")
            .whereField("user1_id", in: [currentUserId, otherUserId])
            .whereField("user2_id", in: [currentUserId, otherUserId])
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let existingMatch = snapshot?.documents.first {
                    print("Match already exists")
                    completion(false)
                    return
                }
                
                let match = Match(user1Id: currentUserId, user2Id: otherUserId, listening: listening)
                
                do {
                    try self.db.collection("matches").addDocument(from: match) { error in
                        if let error = error {
                            print("Error creating match: \(error)")
                            completion(false)
                        } else {
                            print("Match created!")
                            completion(true)
                        }
                    }
                } catch {
                    print("Error encoding match: \(error)")
                    completion(false)
                }
            }
    }
    

    
    
    func acceptMatch(_ match: Match, myUserId: String, completion: @escaping (Bool) -> Void) {
        print("ACCEPT MATCH CALLED")
        print("   Match ID: \(match.id ?? "nil")")
        print("   My User ID: \(myUserId)")
        print("   User1: \(match.user1Id), User2: \(match.user2Id)")
        
        guard let matchId = match.id else {
            print("No match ID")
            completion(false)
            return
        }
        
        // Determine which field to update
        let field = match.user1Id == myUserId ? "user1_accepted" : "user2_accepted"
        print("   Updating field: \(field)")
        
        // First check if document still exists
        db.collection("matches").document(matchId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print(" Error checking match: \(error)")
                completion(false)
                return
            }
            
            guard document?.exists == true else {
                print(" Match document no longer exists")
                completion(false)
                return
            }
            
            print("Document exists, updating...")
            
            // Update the match
            self.db.collection("matches").document(matchId).updateData([
                field: true
            ]) { error in
                if let error = error {
                    print("Error updating match: \(error)")
                    completion(false)
                    return
                }
                
                print("Match field updated successfully!")
                
                // Check if both accepted - create chat
                var updatedMatch = match
                if match.user1Id == myUserId {
                    updatedMatch.user1Accepted = true
                } else {
                    updatedMatch.user2Accepted = true
                }
                
                print("   Updated match status: user1=\(updatedMatch.user1Accepted), user2=\(updatedMatch.user2Accepted)")
                
                if updatedMatch.isBothAccepted {
                    print("Both users accepted - creating chat!")
                    self.createChat(for: updatedMatch)
                } else {
                    print(" Waiting for other user to accept")
                }
                
                completion(true)
            }
        }
    }
    
    
    func declineMatch(_ match: Match, completion: @escaping (Bool) -> Void) {
        print("DECLINE MATCH CALLED")
        print(" Match ID: \(match.id ?? "nil")")
        
        guard let matchId = match.id else {
            print(" No match ID")
            completion(false)
            return
        }
        
        print("Declining match: \(matchId)")
        
        // First check if document still exists
        db.collection("matches").document(matchId).getDocument { [weak self] document, error in
            if let error = error {
                print(" Error checking match: \(error)")
                completion(false)
                return
            }
            
            guard document?.exists == true else {
                print(" Match already deleted")
                completion(true)
                return
            }
            
            print("Deleting match document...")
            
            // Delete the match
            self?.db.collection("matches").document(matchId).delete { error in
                if let error = error {
                    print(" Error deleting match: \(error)")
                    completion(false)
                } else {
                    print(" Match deleted successfully")
                    completion(true)
                }
            }
        }
    }
    
    private func createChat(for match: Match) {
        guard let matchId = match.id else { return }
        
        let chat = Chat(matchId: matchId, user1Id: match.user1Id, user2Id: match.user2Id)
        
        do {
            let chatRef = try db.collection("chats").addDocument(from: chat) { error in
                if let error = error {
                    print("Error creating chat: \(error)")
                    return
                }
                print("Chat created!")
            }
            
            // Update match with chat ID
            db.collection("matches").document(matchId).updateData([
                "chat_id": chatRef.documentID
            ])
            
        } catch {
            print("Error encoding chat: \(error)")
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
        NavigationView {
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
                            .foregroundColor(.gray)
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
            print("Not ready for discovery")
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
            
            if success {
                print(" Match request sent!")
                dismiss()
            } else {
                print("Match already exists or failed")
                // Still dismiss - the match exists!
                dismiss()
            }
        }
    }
}
