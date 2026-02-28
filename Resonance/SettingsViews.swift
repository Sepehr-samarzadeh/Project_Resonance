//
//  SettingsViews.swift
//  Resonance
//
//  Created by Sepehr on 28/02/2026.
//

import SwiftUI
import UserNotifications

// MARK: - Notifications Settings

struct NotificationsSettingsView: View {
    @AppStorage("notif_matches") private var matchNotifications = true
    @AppStorage("notif_messages") private var messageNotifications = true
    @AppStorage("notif_discovery") private var discoveryNotifications = true
    @State private var systemPermissionGranted: Bool?
    
    var body: some View {
        Form {
            Section {
                if let granted = systemPermissionGranted, !granted {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Notifications Disabled")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Text("Enable notifications in Settings to receive alerts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section("Notification Types") {
                Toggle(isOn: $matchNotifications) {
                    Label("Match Requests", systemImage: "heart.fill")
                }
                .tint(.green)
                
                Toggle(isOn: $messageNotifications) {
                    Label("New Messages", systemImage: "message.fill")
                }
                .tint(.green)
                
                Toggle(isOn: $discoveryNotifications) {
                    Label("Discovery Alerts", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tint(.green)
            }
            
            Section {
                Text("Notification preferences are saved locally. Push notification delivery requires notifications to be enabled in your device Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkNotificationPermission()
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let granted = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                systemPermissionGranted = granted
            }
        }
    }
}


// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @AppStorage("privacy_show_listening") private var showListeningActivity = true
    @AppStorage("privacy_show_profile") private var showInDiscovery = true
    @AppStorage("privacy_show_online") private var showOnlineStatus = true
    
    var body: some View {
        Form {
            Section("Visibility") {
                Toggle(isOn: $showListeningActivity) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Listening Activity")
                        Text("Let others see what you're playing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.green)
                
                Toggle(isOn: $showInDiscovery) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Appear in Discovery")
                        Text("Show up in other users' Discover tab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.green)
                
                Toggle(isOn: $showOnlineStatus) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Online Status")
                        Text("Display when you're active in the app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.green)
            }
            
            Section("Data") {
                NavigationLink {
                    BlockedUsersListView()
                } label: {
                    Label("Blocked Users", systemImage: "hand.raised.fill")
                }
                
                HStack {
                    Label("Data Requests", systemImage: "doc.text.fill")
                    Spacer()
                    Text("Contact Support")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Text("Privacy preferences are saved locally on your device. Some settings may take a moment to take effect.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}


// MARK: - Blocked Users List

struct BlockedUsersListView: View {
    @StateObject private var blockManager = BlockManager.shared
    @State private var blockedUsers: [AppUser] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if blockedUsers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No blocked users")
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(blockedUsers, id: \.id) { user in
                        HStack(spacing: 12) {
                            ProfileImageView(
                                imageUrl: user.imageUrl,
                                size: 40,
                                fallbackName: user.name
                            )
                            
                            Text(user.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button("Unblock") {
                                Task {
                                    guard let myId = UserManager.shared.getCurrentUserId() else { return }
                                    try? await BlockManager.shared.unblockUser(blockerId: myId, blockedId: user.id)
                                    await loadBlockedUsers()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockedUsers()
        }
    }
    
    private func loadBlockedUsers() async {
        isLoading = true
        let db = FirebaseFirestore.Firestore.firestore()
        var users: [AppUser] = []
        
        for blockedId in blockManager.blockedUserIds {
            let doc = try? await db.collection("users").document(blockedId).getDocument()
            if let data = doc?.data(), let user = AppUser(document: data) {
                users.append(user)
            }
        }
        
        blockedUsers = users
        isLoading = false
    }
}


// MARK: - About View

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Resonance")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            
            Section("About") {
                Text("Resonance connects people through their music taste. Powered by Spotify, Resonance detects what you're listening to and matches you with people playing the same songs and artists — in real time.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Section("Links") {
                Link(destination: URL(string: "https://github.com/Sepehr-samarzadeh/Project_Resonance")!) {
                    Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                
                Link(destination: URL(string: "mailto:support@resonanceapp.com")!) {
                    Label("Contact Support", systemImage: "envelope.fill")
                }
            }
            
            Section("Legal") {
                NavigationLink("Privacy Policy") {
                    ScrollView {
                        Text(privacyPolicyText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .navigationTitle("Privacy Policy")
                    .navigationBarTitleDisplayMode(.inline)
                }
                
                NavigationLink("Terms of Service") {
                    ScrollView {
                        Text(termsOfServiceText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .navigationTitle("Terms of Service")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            
            Section {
                HStack {
                    Text("Made with")
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("and great music")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private var privacyPolicyText: String {
        """
        Privacy Policy for Resonance
        
        Last updated: February 2026
        
        1. Information We Collect
        We collect your Spotify display name, profile image URL, and listening activity when you use the app. We do not collect your Spotify password or full account credentials.
        
        2. How We Use Your Information
        Your listening activity is used solely to match you with other users who share similar music taste. Your profile information is displayed to other users you match with.
        
        3. Data Storage
        Your data is stored securely using Google Firebase services. We retain your data only as long as your account is active.
        
        4. Data Sharing
        We do not sell or share your personal data with third parties. Your listening activity is visible to other Resonance users during active sessions.
        
        5. Account Deletion
        You can delete your account at any time from the Profile tab. This permanently removes all your data from our servers.
        
        6. Contact
        For questions about this privacy policy, contact us at support@resonanceapp.com.
        """
    }
    
    private var termsOfServiceText: String {
        """
        Terms of Service for Resonance
        
        Last updated: February 2026
        
        By using Resonance, you agree to the following terms:
        
        1. Eligibility: You must be at least 13 years old and have a valid Spotify account.
        
        2. Acceptable Use: You agree not to harass, spam, or abuse other users. Violations may result in account suspension.
        
        3. Content: You are responsible for all messages you send. We reserve the right to remove content that violates these terms.
        
        4. Service Availability: Resonance is provided "as is." We do not guarantee uninterrupted service.
        
        5. Spotify: Resonance is not affiliated with Spotify. Your use of Spotify is governed by Spotify's own terms of service.
        
        6. Changes: We may update these terms at any time. Continued use of the app constitutes acceptance of updated terms.
        """
    }
}

import FirebaseFirestore
