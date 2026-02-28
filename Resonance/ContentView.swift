//
//  ContentView.swift
//  Resonance
//
//  Created by Sepehr on 19/11/2025.
//

import SwiftUI
import FirebaseFirestore


struct ContentView: View {
    var body: some View {
        TabView {
            // Tab 1: Now Playing
            NowPlayingView()
                .tabItem {
                    Image(systemName: "music.note")
                    Text("Now Playing")
                }
            
            // Tab 2: Discovery (NEW!)
            DiscoveryView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Discover")
                }
            
            // Tab 3: Match Requests (NEW!)
            PendingMatchesView()
                .tabItem {
                    Image(systemName: "bell.badge")
                    Text("Requests")
                }
            
            // Tab 4: Chats (NEW!)
            ActiveMatchesView()
                .tabItem {
                    Image(systemName: "message")
                    Text("Chats")
                }
            
            // Tab 5: Profile/Login
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
    }
}

// Simple Profile View
struct ProfileView: View {
    @State private var isLoggedIn = false
    
    var body: some View {
    
                
                Button {
                    startSpotifyAuthorization()
                } label: {
                    Text("Connect Spotify")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    


#Preview {
    ContentView()
}
