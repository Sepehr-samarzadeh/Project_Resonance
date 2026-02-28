import Foundation
import FirebaseFirestore
import Combine


@MainActor
class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()
    
    @Published var currentListening: CurrentListening?
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    
    private var timer: Timer?
    private let db = Firestore.firestore()
    private var currentUserId: String?
    
    private init() {}
    
    func startTracking(userId: String) {
        self.currentUserId = userId
        errorMessage = nil
        
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
            db.collection("current_listening").document(userId).delete()
        }
        
        currentUserId = nil
        currentListening = nil
        isPlaying = false
        errorMessage = nil
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
                    self.errorMessage = nil
                }
                
                self.saveToFirebase(listening: listening)
                
            case .failure(let error):
                if let spotifyError = error as? SpotifyError {
                    switch spotifyError {
                    case .nothingPlaying:
                        self.removeFromFirebase(userId: userId)
                        DispatchQueue.main.async {
                            self.currentListening = nil
                            self.isPlaying = false
                            self.errorMessage = nil
                        }
                    case .tokenRefreshFailed, .noAccessToken, .noRefreshToken:
                        DispatchQueue.main.async {
                            self.errorMessage = "Session expired. Please reconnect Spotify in Profile."
                        }
                    default:
                        DispatchQueue.main.async {
                            self.errorMessage = spotifyError.localizedDescription
                        }
                    }
                } else if (error as NSError).code == 204 {
                    self.removeFromFirebase(userId: userId)
                    DispatchQueue.main.async {
                        self.currentListening = nil
                        self.isPlaying = false
                    }
                }
            }
        }
    }
    
    private func saveToFirebase(listening: CurrentListening) {
        let data = listening.toDictionary()
        db.collection("current_listening").document(listening.id).setData(data)
    }
    
    private func removeFromFirebase(userId: String) {
        db.collection("current_listening").document(userId).delete()
    }
    
    func refreshNowPlaying() {
        Task {
            await updateNowPlaying()
        }
    }
}
