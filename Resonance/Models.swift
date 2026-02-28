//
//  Models.swift
//  Resonance
//
//  Created by Sepehr on 14/12/2025.
//

import Foundation
import FirebaseFirestore



struct SpotifyUser: Codable {
    let id: String
    let displayName: String?
    let images: [SpotifyImage]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case images
    }
}

struct SpotifyImage: Codable {
    let url: String
}

struct SpotifyCurrentlyPlaying: Codable {
    let item: SpotifyTrack?
    let isPlaying: Bool
    
    enum CodingKeys: String, CodingKey {
        case item
        case isPlaying = "is_playing"
    }
}

struct SpotifyTrack: Codable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
}

struct SpotifyArtist: Codable {
    let id: String
    let name: String
}

struct SpotifyAlbum: Codable {
    let images: [SpotifyImage]
}

// Spotify Top Artists response
struct SpotifyTopArtistsResponse: Codable {
    let items: [SpotifyArtistFull]
}

struct SpotifyArtistFull: Codable {
    let id: String
    let name: String
    let genres: [String]?
    let images: [SpotifyImage]?
}

// Spotify Recently Played response
struct SpotifyRecentlyPlayedResponse: Codable {
    let items: [SpotifyPlayHistoryItem]
}

struct SpotifyPlayHistoryItem: Codable {
    let track: SpotifyTrack
}

//firebase models

/// User in database
struct AppUser: Codable, Identifiable {
    var id: String // Spotify ID
    let name: String
    let imageUrl: String?
    var isOnline: Bool
    var lastActive: Date
    var bio: String?
    var favoriteGenres: [String]?
    var topArtistIds: [String]?
    var topArtistNames: [String]?
    var fcmToken: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, bio
        case imageUrl = "image_url"
        case isOnline = "is_online"
        case lastActive = "last_active"
        case favoriteGenres = "favorite_genres"
        case topArtistIds = "top_artist_ids"
        case topArtistNames = "top_artist_names"
        case fcmToken = "fcm_token"
    }
    
    // Convert from Spotify user
    init(from spotifyUser: SpotifyUser) {
        self.id = spotifyUser.id
        self.name = spotifyUser.displayName ?? "Unknown"
        self.imageUrl = spotifyUser.images?.first?.url
        self.isOnline = true
        self.lastActive = Date()
        self.bio = nil
        self.favoriteGenres = nil
        self.topArtistIds = nil
        self.topArtistNames = nil
        self.fcmToken = nil
    }
    
    // Convert to Firebase dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "image_url": imageUrl as Any,
            "is_online": isOnline,
            "last_active": Timestamp(date: lastActive)
        ]
        if let bio = bio { dict["bio"] = bio }
        if let genres = favoriteGenres { dict["favorite_genres"] = genres }
        if let ids = topArtistIds { dict["top_artist_ids"] = ids }
        if let names = topArtistNames { dict["top_artist_names"] = names }
        if let token = fcmToken { dict["fcm_token"] = token }
        return dict
    }
}

/// What user is currently listening to
struct CurrentListening: Codable, Identifiable {
    var id: String // User ID (document ID)
    let trackId: String
    let trackName: String
    let artistId: String
    let artistName: String
    let imageUrl: String?
    let isPlaying: Bool
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case trackId = "track_id"
        case trackName = "track_name"
        case artistId = "artist_id"
        case artistName = "artist_name"
        case imageUrl = "image_url"
        case isPlaying = "is_playing"
        case updatedAt = "updated_at"
    }
    
    // Basic memberwise init
    init(userId: String, trackId: String, trackName: String, artistId: String, artistName: String, imageUrl: String?, isPlaying: Bool) {
        self.id = userId
        self.trackId = trackId
        self.trackName = trackName
        self.artistId = artistId
        self.artistName = artistName
        self.imageUrl = imageUrl
        self.isPlaying = isPlaying
        self.updatedAt = Date()
    }
    
    // Create from Spotify response
    init(userId: String, from spotify: SpotifyCurrentlyPlaying) {
        self.id = userId
        
        if let track = spotify.item {
            self.trackId = track.id
            self.trackName = track.name
            self.artistId = track.artists.first?.id ?? ""
            self.artistName = track.artists.first?.name ?? "Unknown"
            self.imageUrl = track.album.images.first?.url
        } else {
            // Not playing
            self.trackId = ""
            self.trackName = ""
            self.artistId = ""
            self.artistName = ""
            self.imageUrl = nil
        }
        
        self.isPlaying = spotify.isPlaying
        self.updatedAt = Date()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "track_id": trackId,
            "track_name": trackName,
            "artist_id": artistId,
            "artist_name": artistName,
            "image_url": imageUrl as Any,
            "is_playing": isPlaying,
            "updated_at": Timestamp(date: updatedAt)
        ]
    }
}


struct Match: Codable, Identifiable {
    var id: String?
    let user1Id: String
    let user2Id: String
    

    let trackName: String
    let artistName: String
    let imageUrl: String?
    

    var user1Accepted: Bool
    var user2Accepted: Bool
    
    
    let createdAt: Date
    

    var chatId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case trackName = "track_name"
        case artistName = "artist_name"
        case imageUrl = "image_url"
        case user1Accepted = "user1_accepted"
        case user2Accepted = "user2_accepted"
        case createdAt = "created_at"
        case chatId = "chat_id"
    }
    
    // create new match
    
    init(user1Id: String, user2Id: String, listening: CurrentListening) {
        self.id = nil
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.trackName = listening.trackName
        self.artistName = listening.artistName
        self.imageUrl = listening.imageUrl
        self.user1Accepted = true  // changed this might get buggy later
        self.user2Accepted = false
        self.createdAt = Date()
        self.chatId = nil
    }
    
    // Both accepted?
    var isBothAccepted: Bool {
        return user1Accepted && user2Accepted
    }
    
    // Get other users ID
    func otherUserId(myId: String) -> String {
        return myId == user1Id ? user2Id : user1Id
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "user1_id": user1Id,
            "user2_id": user2Id,
            "track_name": trackName,
            "artist_name": artistName,
            "image_url": imageUrl as Any,
            "user1_accepted": user1Accepted,
            "user2_accepted": user2Accepted,
            "created_at": Timestamp(date: createdAt)
        ]
        
        if let chatId = chatId {
            dict["chat_id"] = chatId
        }
        
        return dict
    }
}


struct Chat: Codable, Identifiable {
    var id: String? // firebase document ID
    let matchId: String
    let user1Id: String
    let user2Id: String
    let createdAt: Date
    var lastMessageAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
    }
    
    // create from match
    init(matchId: String, user1Id: String, user2Id: String) {
        self.id = nil
        self.matchId = matchId
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.createdAt = Date()
        self.lastMessageAt = Date()
    }
    
    // get other users ID
    func otherUserId(myId: String) -> String {
        return myId == user1Id ? user2Id : user1Id
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "match_id": matchId,
            "user1_id": user1Id,
            "user2_id": user2Id,
            "created_at": Timestamp(date: createdAt),
            "last_message_at": Timestamp(date: lastMessageAt)
        ]
    }
}


struct Message: Codable, Identifiable {
    var id: String? // firebase document ID
    let chatId: String
    let senderId: String
    let text: String
    let sentAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case senderId = "sender_id"
        case text
        case sentAt = "sent_at"
    }
    
    // Create new message
    init(chatId: String, senderId: String, text: String) {
        self.id = nil
        self.chatId = chatId
        self.senderId = senderId
        self.text = text
        self.sentAt = Date()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "chat_id": chatId,
            "sender_id": senderId,
            "text": text,
            "sent_at": Timestamp(date: sentAt)
        ]
    }
}



extension AppUser {
    // create from Firebase document
    init?(document: [String: Any]) {
        guard let id = document["id"] as? String,
              let name = document["name"] as? String,
              let isOnline = document["is_online"] as? Bool,
              let lastActiveTimestamp = document["last_active"] as? Timestamp else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.imageUrl = document["image_url"] as? String
        self.isOnline = isOnline
        self.lastActive = lastActiveTimestamp.dateValue()
        self.bio = document["bio"] as? String
        self.favoriteGenres = document["favorite_genres"] as? [String]
        self.topArtistIds = document["top_artist_ids"] as? [String]
        self.topArtistNames = document["top_artist_names"] as? [String]
        self.fcmToken = document["fcm_token"] as? String
    }
}

extension CurrentListening {
    // create from Firebase document
    init?(userId: String, document: [String: Any]) {
        guard let trackId = document["track_id"] as? String,
              let trackName = document["track_name"] as? String,
              let artistId = document["artist_id"] as? String,
              let artistName = document["artist_name"] as? String,
              let isPlaying = document["is_playing"] as? Bool,
              let updatedAtTimestamp = document["updated_at"] as? Timestamp else {
            return nil
        }
        
        self.id = userId
        self.trackId = trackId
        self.trackName = trackName
        self.artistId = artistId
        self.artistName = artistName
        self.imageUrl = document["image_url"] as? String
        self.isPlaying = isPlaying
        self.updatedAt = updatedAtTimestamp.dateValue()
    }
}
