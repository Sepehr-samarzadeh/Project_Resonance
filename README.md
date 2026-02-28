# Resonance 🎵

A music-based social app that connects people through what they're listening to — in real time.

Resonance uses Spotify to detect your currently playing track and matches you with others listening to the same song or artist. Think of it as a dating/social app where your music taste *is* your profile.

## How It Works

1. **Connect Spotify** — Sign in with your Spotify account via secure PKCE OAuth
2. **Play Music** — Open Spotify and start listening to something
3. **Get Discovered** — Resonance detects your track and shows you others playing the same song or artist
4. **Match & Chat** — Send a match request, and if they accept, start a conversation

## Features

- **Real-time Discovery** — Find people listening to the same track or artist as you, right now
- **Shared Taste Matching** — Get matched with users who share your top Spotify artists
- **Profile Editing** — Add a bio, select favorite genres, sync your top artists from Spotify
- **Chat** — Message your matches directly in the app
- **Push Notifications** — Get notified about new matches and messages (via Firebase Cloud Messaging)
- **Block & Report** — Full moderation tools for user safety (Apple Guidelines 1.2)
- **Onboarding** — First-launch walkthrough explaining how discovery works
- **Image Caching** — Custom `CachedAsyncImage` with in-memory + disk caching
- **Account Deletion** — Delete your account and all data at any time

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 16+) |
| Auth | Spotify PKCE OAuth |
| Backend | Firebase Firestore (real-time) |
| Push | Firebase Cloud Messaging |
| Music Data | Spotify Web API |
| Architecture | Singleton managers, async/await, @MainActor |

## Project Structure

```
Resonance/
├── ResonanceApp.swift          # App entry point, OAuth callback
├── ContentView.swift           # Auth gate + TabView
├── AppDelegate.swift           # Firebase config + push notifications
├── SceneDelegate.swift         # URL scheme handling
│
├── Models.swift                # All data models (Spotify + Firebase)
├── Secrets.swift               # API keys (gitignored)
│
├── SpotifyAPIManager.swift     # Spotify API calls + token refresh
├── CodeGen.swift               # PKCE auth code generation
├── SpFetcher.swift             # Spotify data fetching
│
├── UserManager.swift           # User registration, profile, account
├── MatchManager.swift          # Discovery, matching, shared taste
├── ChatManager.swift           # Real-time messaging
├── NowPlayingManager.swift     # Spotify polling + Firebase sync
├── BlockManager.swift          # Block/report system
├── NotificationHelper.swift    # Push notification triggers
│
├── NowPlayingView.swift        # Now Playing tab
├── MatchViews.swift            # Pending + Active matches UI
├── ChatView.swift              # Chat interface + moderation
├── EditProfileView.swift       # Profile editor (bio, genres, artists)
├── OnboardingView.swift        # First-launch walkthrough
├── SettingsViews.swift         # Notifications, Privacy, About screens
├── UIComponents.swift          # Reusable components + Profile view
└── CachedAsyncImage.swift      # Image caching layer
```

## Setup

1. Clone the repo
2. Create `Resonance/Secrets.swift` with your credentials:
   ```swift
   enum Secrets {
       static let spotifyClientId = "YOUR_SPOTIFY_CLIENT_ID"
       static let spotifyRedirectUri = "YOUR_REDIRECT_URI"
   }
   ```
3. Add your `GoogleService-Info.plist` from the Firebase console
4. Open `Resonance.xcodeproj` in Xcode and build

## Requirements

- iOS 16+
- Xcode 15+
- Spotify account (free or premium)
- Firebase project with Firestore + Auth + Cloud Messaging

## License

This project is for educational and portfolio purposes.
