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
        let hasToken = UserDefaults.standard.string(forKey: "spotify_access_token") != nil
        let hasUserId = UserManager.shared.getCurrentUserId() != nil
        isLoggedIn = hasToken && hasUserId
        
        if isLoggedIn, let userId = UserManager.shared.getCurrentUserId() {
            BlockManager.shared.startListening(userId: userId)
        }
    }
}

extension Notification.Name {
    static let didCompleteSpotifyLogin = Notification.Name("didCompleteSpotifyLogin")
}

#Preview {
    ContentView()
}
