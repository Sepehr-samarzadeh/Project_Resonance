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
        
        do {
            let playing = try await SpotifyAPIManager.shared.getCurrentlyPlaying()
            let listening = CurrentListening(userId: userId, from: playing)
            self.currentListening = listening
            self.isPlaying = playing.isPlaying
            self.errorMessage = nil
            saveToFirebase(listening: listening)
        } catch {
            if let spotifyError = error as? SpotifyError {
                switch spotifyError {
                case .nothingPlaying:
                    removeFromFirebase(userId: userId)
                    self.currentListening = nil
                    self.isPlaying = false
                    self.errorMessage = nil
                case .tokenRefreshFailed, .noAccessToken, .noRefreshToken:
                    self.errorMessage = "Session expired. Please reconnect Spotify in Profile."
                default:
                    self.errorMessage = spotifyError.localizedDescription
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
