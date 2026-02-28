//
//  UIComponents.swift
//  Resonance
//
//  Created by Sepehr on 22/12/2025.
//

import SwiftUI

// MARK: - Reusable Profile Image Component
struct ProfileImageView: View {
    let imageUrl: String?
    let size: CGFloat
    let fallbackName: String?
    
    @State private var loadFailed = false
    
    init(imageUrl: String?, size: CGFloat = 50, fallbackName: String? = nil) {
        self.imageUrl = imageUrl
        self.size = size
        self.fallbackName = fallbackName
    }
    
    var body: some View {
        Group {
            if let urlString = imageUrl, !urlString.isEmpty, let url = URL(string: urlString), !loadFailed {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .onAppear {
                                print("✅ Image loaded successfully: \(urlString)")
                            }
                    case .failure(let error):
                        fallbackInitials
                            .onAppear {
                                print("❌ Image load failed for: \(urlString)")
                                print("   Error: \(error)")
                                loadFailed = true
                            }
                    @unknown default:
                        fallbackInitials
                    }
                }
            } else {
                fallbackInitials
                    .onAppear {
                        if let urlString = imageUrl {
                            print("⚠️ Using fallback for URL: \(urlString)")
                        } else {
                            print("⚠️ No image URL provided, using initials")
                        }
                    }
            }
        }
    }
    
    var fallbackInitials: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.green, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(getInitials())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
    
    func getInitials() -> String {
        guard let name = fallbackName, !name.isEmpty else {
            return "?"
        }
        
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

// MARK: - Beautiful Login Screen
struct BeautifulLoginView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.3),
                    Color.black
                ],
                startPoint: isAnimating ? .topLeading : .bottomLeading,
                endPoint: isAnimating ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            
            // Floating music notes
            ForEach(0..<5) { index in
                Image(systemName: ["music.note", "music.note.list", "guitars", "headphones", "waveform"].randomElement()!)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white.opacity(0.1))
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: CGFloat.random(in: -300...300)
                    )
                    .rotationEffect(.degrees(Double.random(in: -30...30)))
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // App icon/logo area
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                        
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.white)
                    }
                    
                    Text("Resonance")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Find people who vibe with your music")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Features list
                VStack(alignment: .leading, spacing: 15) {
                    FeatureRow(icon: "music.note", text: "See what others are listening to")
                    FeatureRow(icon: "person.2.fill", text: "Match with people who share your taste")
                    FeatureRow(icon: "message.fill", text: "Chat about your favorite songs")
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Login button
                Button {
                    startSpotifyAuthorization()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.circle.fill")
                            .font(.system(size: 24))
                        
                        Text("Connect with Spotify")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color(red: 0.1, green: 0.8, blue: 0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(30)
                    .shadow(color: Color.green.opacity(0.5), radius: 20, y: 10)
                }
                .padding(.horizontal, 40)
                
                Text("Separate yourself from the crowd.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - Better Profile View
struct BetterProfileView: View {
    @State private var user: AppUser?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 100)
                    } else if let user = user {
                        // Profile Header
                        VStack(spacing: 20) {
                            ProfileImageView(
                                imageUrl: user.imageUrl,
                                size: 120,
                                fallbackName: user.name
                            )
                            .shadow(color: Color.green.opacity(0.3), radius: 20)
                            
                            Text(user.name)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(user.isOnline ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                
                                Text(user.isOnline ? "Online" : "Offline")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 60)
                        
                        // Stats Cards
                        HStack(spacing: 15) {
                            StatCard(title: "Matches", value: "0", icon: "heart.fill")
                            StatCard(title: "Chats", value: "0", icon: "message.fill")
                        }
                        .padding(.horizontal)
                        
                        // Settings Section
                        VStack(spacing: 0) {
                            SettingRow(icon: "bell.fill", title: "Notifications", showChevron: true)
                            Divider().padding(.leading, 50)
                            SettingRow(icon: "person.fill.questionmark", title: "Privacy", showChevron: true)
                            Divider().padding(.leading, 50)
                            SettingRow(icon: "info.circle.fill", title: "About", showChevron: true)
                        }
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)
                        .padding(.horizontal)
                        
                        // Logout Button
                        Button {
                            logout()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Logout")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                    } else {
                        // Not logged in
                        BeautifulLoginView()
                    }
                }
            }
        }
        .onAppear {
            loadUser()
        }
    }
    
    func loadUser() {
        isLoading = true
        
        if let userId = UserManager.shared.getCurrentUserId() {
            let db = Firestore.firestore()
            db.collection("users").document(userId).getDocument { doc, error in
                if let data = doc?.data(),
                   let user = AppUser(document: data) {
                    self.user = user
                }
                isLoading = false
            }
        } else {
            isLoading = false
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: "spotify_access_token")
        UserDefaults.standard.removeObject(forKey: "spotify_refresh_token")
        UserDefaults.standard.removeObject(forKey: "current_user_id")
        NowPlayingManager.shared.stopTracking()
        user = nil
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
}

// MARK: - Setting Row
struct SettingRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    BeautifulLoginView()
        .preferredColorScheme(.dark)
}

import FirebaseFirestore
