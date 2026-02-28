//
//  NowPlayingView.swift
//  Resonance
//
//  Created by Sepehr on 14/12/2025.
//

import SwiftUI

struct NowPlayingView: View {
    @StateObject private var nowPlayingManager = NowPlayingManager.shared
    @State private var isTracking = false
    @State private var currentUserId: String?
    
    var body: some View {
        
        VStack(spacing: 20) {
            
            Text("Now Playing")
                .font(.largeTitle)
                .bold()
            
            if let listening = nowPlayingManager.currentListening {
                VStack(spacing: 15) {
                    // Album Art
                    if let imageUrl = listening.imageUrl,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 200, height: 200)
                        .cornerRadius(10)
                        
                    }
                    
                    // Track Info
                    VStack(spacing: 8) {
                        Text(listening.trackName)
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)
                        
                        Text(listening.artistName)
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Image(systemName: listening.isPlaying ? "play.fill" : "pause.fill")
                            Text(listening.isPlaying ? "Playing" : "Paused")
                        }
                        .foregroundColor(listening.isPlaying ? .green : .orange)
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 15) {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    
                    Text("Not playing anything")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Start playing music on Spotify")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Error Banner
            if let error = nowPlayingManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Control Buttons
            VStack(spacing: 15) {
                if isTracking {
                    Button {
                        nowPlayingManager.refreshNowPlaying()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Now")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button {
                        stopTracking()
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop Tracking")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else {
                    Button {
                        startTracking()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Tracking")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            checkUserAndStartTracking()
        }
    }
    
    func checkUserAndStartTracking() {
        if let userId = UserManager.shared.getCurrentUserId() {
            self.currentUserId = userId
            return
        }
        
        Task {
            do {
                let spotifyUser = try await SpotifyAPIManager.shared.getCurrentUserProfile()
                UserManager.shared.registerUser(spotifyUser: spotifyUser) { success in
                    if success {
                        self.currentUserId = spotifyUser.id
                    }
                }
            } catch {
                // User not logged in or network error — handled by login flow
            }
        }
    }
    
    func startTracking() {
        guard let userId = currentUserId else {
            return
        }
        
        NowPlayingManager.shared.startTracking(userId: userId)
        UserManager.shared.updateOnlineStatus(userId: userId, isOnline: true)
        isTracking = true
    }
    
    func stopTracking() {
        if let userId = currentUserId {
            UserManager.shared.updateOnlineStatus(userId: userId, isOnline: false)
        }
        
        NowPlayingManager.shared.stopTracking()
        isTracking = false
    }
}

#Preview {
    NowPlayingView()
}
