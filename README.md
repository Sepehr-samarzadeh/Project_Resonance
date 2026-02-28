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
