//
//  EditProfileView.swift
//  Resonance
//
//  Created by Sepehr on 28/02/2026.
//

import SwiftUI

struct EditProfileView: View {
    let user: AppUser
    
    @Environment(\.dismiss) private var dismiss
    @State private var bio: String
    @State private var selectedGenres: Set<String>
    @State private var topArtists: [SpotifyArtistFull] = []
    @State private var isSaving = false
    @State private var isFetchingArtists = false
    @State private var saveError: String?
    @State private var showSuccess = false
    
    private let allGenres = [
        "Pop", "Rock", "Hip-Hop", "R&B", "Jazz", "Classical",
        "Electronic", "Country", "Latin", "Indie", "Metal",
        "Folk", "Blues", "Reggae", "Punk", "Soul", "K-Pop", "Afrobeats"
    ]
    
    init(user: AppUser) {
        self.user = user
        _bio = State(initialValue: user.bio ?? "")
        _selectedGenres = State(initialValue: Set(user.favoriteGenres ?? []))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Bio Section
                Section("About You") {
                    TextField("Tell others about yourself...", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Text("\(bio.count)/200")
                        .font(.caption2)
                        .foregroundColor(bio.count > 200 ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                // Favorite Genres
                Section("Favorite Genres") {
                    Text("Select genres you love")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 90))
                    ], spacing: 8) {
                        ForEach(allGenres, id: \.self) { genre in
                            GenreChip(
                                genre: genre,
                                isSelected: selectedGenres.contains(genre)
                            ) {
                                if selectedGenres.contains(genre) {
                                    selectedGenres.remove(genre)
                                } else if selectedGenres.count < 5 {
                                    selectedGenres.insert(genre)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Text("\(selectedGenres.count)/5 selected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Top Artists from Spotify
                Section("Your Top Artists") {
                    if isFetchingArtists {
                        HStack {
                            Spacer()
                            ProgressView("Fetching from Spotify...")
                            Spacer()
                        }
                    } else if topArtists.isEmpty {
                        Button {
                            fetchTopArtists()
                        } label: {
                            HStack {
                                Image(systemName: "music.note.list")
                                Text("Sync Top Artists from Spotify")
                            }
                        }
                        
                        if let existingNames = user.topArtistNames, !existingNames.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Currently synced:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(existingNames, id: \.self) { name in
                                    HStack(spacing: 8) {
                                        Image(systemName: "music.mic")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text(name)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    } else {
                        ForEach(topArtists, id: \.id) { artist in
                            HStack(spacing: 12) {
                                if let imageUrl = artist.images?.last?.url,
                                   let url = URL(string: imageUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Circle().fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 36, height: 36)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artist.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    if let genres = artist.genres, !genres.isEmpty {
                                        Text(genres.prefix(2).joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Text("These will be used for matching")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Save
                Section {
                    Button {
                        saveProfile()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save Profile")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || bio.count > 200)
                    .listRowBackground(Color.green)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Profile Updated", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been saved successfully.")
            }
            .alert("Error", isPresented: .init(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK") { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }
    
    func fetchTopArtists() {
        isFetchingArtists = true
        
        Task {
            do {
                topArtists = try await SpotifyAPIManager.shared.getTopArtists(limit: 10)
            } catch {
                saveError = "Could not fetch top artists: \(error.localizedDescription)"
            }
            isFetchingArtists = false
        }
    }
    
    func saveProfile() {
        guard let userId = UserManager.shared.getCurrentUserId() else { return }
        
        isSaving = true
        saveError = nil
        
        Task {
            do {
                // Save bio + genres
                try await UserManager.shared.updateProfile(
                    userId: userId,
                    bio: bio.isEmpty ? nil : bio,
                    favoriteGenres: selectedGenres.isEmpty ? nil : Array(selectedGenres)
                )
                
                // Save top artists if fetched
                if !topArtists.isEmpty {
                    let ids = topArtists.map { $0.id }
                    let names = topArtists.map { $0.name }
                    try await UserManager.shared.updateTopArtists(
                        userId: userId,
                        artistIds: ids,
                        artistNames: names
                    )
                }
                
                isSaving = false
                showSuccess = true
            } catch {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }
}

// MARK: - Genre Chip
struct GenreChip: View {
    let genre: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(genre)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.green : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(genre), \(isSelected ? "selected" : "not selected")")
    }
}
