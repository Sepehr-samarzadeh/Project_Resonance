import Foundation
import FirebaseFirestore
import Combine


@MainActor

class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()
    
    @Published var currentListening: CurrentListening?
    @Published var isPlaying: Bool = false
    
    private var timer: Timer?
    private let db = Firestore.firestore()
    private var currentUserId: String?
    
    private init() {}
    
    
 
    func startTracking(userId: String) {
        self.currentUserId = userId
        print("Started tracking now playing for user: \(userId)")
        
        Task {
            await updateNowPlaying()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateNowPlaying()
            }
        }
    }
    
    func stopTracking() {
        timer?.invalidate()
        timer = nil
        
        if let userId = currentUserId {
            db.collection("current_listening").document(userId).delete { error in
                if let error = error {
                    print("Error removing listening data: \(error)")
                } else {
                    print("Removed listening data from Firebase")
                }
            }
        }
        
        currentUserId = nil
        currentListening = nil
        isPlaying = false
        
        print("Stopped tracking now playing")
    }
    
    
    private func updateNowPlaying() async {
        guard let userId = currentUserId else { return }
        
        SpotifyAPIManager.shared.getCurrentlyPlaying { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let playing):
                let listening = CurrentListening(userId: userId, from: playing)
                
                DispatchQueue.main.async {
                    self.currentListening = listening
                    self.isPlaying = playing.isPlaying
                }
                
                
                self.saveToFirebase(listening: listening)
                
                print("Now playing: \(listening.trackName) by \(listening.artistName)")
                
            case .failure(let error):
                
                if (error as NSError).code == 204 {
                    
                    self.removeFromFirebase(userId: userId)
                    
                    DispatchQueue.main.async {
                        self.currentListening = nil
                        self.isPlaying = false
                    }
                    
                    print("Nothing playing")
                } else {
                    print("Error fetching now playing: \(error)")
                }
            }
        }
    }
    
    private func saveToFirebase(listening: CurrentListening) {
        let data = listening.toDictionary()
        
        db.collection("current_listening").document(listening.id).setData(data) { error in
            if let error = error {
                print("error saving to Firebase: \(error)")
            } else {
                print("Saved to Firebase: \(listening.trackName)")
            }
        }
    }
    
    private func removeFromFirebase(userId: String) {
        db.collection("current_listening").document(userId).delete { error in
            if let error = error {
                print("error removing from Firebase: \(error)")
            } else {
                print("removed from Firebase")
            }
        }
    }
    
    func refreshNowPlaying() {
        Task {
            await updateNowPlaying()
        }
    }
}
