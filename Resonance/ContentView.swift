//
//  ContentView.swift
//  Resonance
//
//  Created by Sepehr on 19/11/2025.
//

import SwiftUI
import FirebaseFirestore


struct ContentView: View {
    @StateObject private var matchManager = MatchManager.shared
    @State private var isLoggedIn = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if isLoggedIn {
                TabView {
                    NowPlayingView()
                        .tabItem {
                            Image(systemName: "music.note")
                            Text("Now Playing")
                        }
                    
                    DiscoveryView()
                        .tabItem {
                            Image(systemName: "person.2")
                            Text("Discover")
                        }
                    
                    PendingMatchesView()
                        .tabItem {
                            Image(systemName: "bell")
                            Text("Requests")
                        }
                        .badge(matchManager.pendingMatches.count)
                    
                    ActiveMatchesView()
                        .tabItem {
                            Image(systemName: "message")
                            Text("Chats")
                        }
                    
                    BetterProfileView(isLoggedIn: $isLoggedIn)
                        .tabItem {
                            Image(systemName: "person.circle")
                            Text("Profile")
                        }
                }
            } else {
                BeautifulLoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .onAppear {
            checkLoginStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didCompleteSpotifyLogin)) { _ in
            checkLoginStatus()
        }
    }
    
    func checkLoginStatus() {
        let hasToken = KeychainHelper.read(key: KeychainHelper.spotifyAccessToken) != nil
        let hasUserId = UserManager.shared.getCurrentUserId() != nil
        
        print("[CHECK] hasToken=\(hasToken), hasUserId=\(hasUserId), current_user_id=\(UserManager.shared.getCurrentUserId() ?? "nil")")
        
        if hasToken && hasUserId {
            isLoggedIn = true
            print("[CHECK] Logged in!")
            
            if let userId = UserManager.shared.getCurrentUserId() {
                BlockManager.shared.startListening(userId: userId)
                
                // Ensure Firebase Auth session is active
                Task {
                    try? await AuthManager.shared.ensureAuthenticated()
                }
            }
        } else if hasToken && !hasUserId {
            print("[CHECK] Token exists but no userId - retrying profile fetch...")
            // Token exists but user profile wasn't registered yet (e.g. profile fetch
            // failed during login). Try to register now before giving up.
            Task { @MainActor in
                do {
                    let spotifyUser = try await SpotifyAPIManager.shared.getCurrentUserProfile()
                    print("[CHECK] Got profile: \(spotifyUser.id)")
                    let registered = await UserManager.shared.registerUser(spotifyUser: spotifyUser)
                    print("[CHECK] registerUser returned: \(registered)")
                    // Re-check now that userId should be set
                    if registered {
                        isLoggedIn = true
                        
                        if let userId = UserManager.shared.getCurrentUserId() {
                            BlockManager.shared.startListening(userId: userId)
                            try? await AuthManager.shared.ensureAuthenticated()
                        }
                    } else {
                        isLoggedIn = false
                    }
                } catch {
                    print("[CHECK] Retry failed: \(error)")
                    // Profile fetch still failing — stay on login screen
                    isLoggedIn = false
                }
            }
        } else {
            print("[CHECK] Not logged in - no token")
            isLoggedIn = false
        }
    }
}

extension Notification.Name {
    static let didCompleteSpotifyLogin = Notification.Name("didCompleteSpotifyLogin")
}

#Preview {
    ContentView()
}
