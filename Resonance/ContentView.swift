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
    
    var body: some View {
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
            
            BetterProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
    }
}


#Preview {
    ContentView()
}
