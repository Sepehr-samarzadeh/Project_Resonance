//
//  CachedAsyncImage.swift
//  Resonance
//
//  A drop-in replacement for AsyncImage that caches downloaded images
//  in an NSCache (memory) + URLCache (disk) layer, eliminating
//  redundant network fetches and loading flashes.
//

import SwiftUI

// MARK: - Image Cache (in-memory)

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - CachedAsyncImage View

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var uiImage: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url, !isLoading else { return }
        
        let key = url.absoluteString
        
        // Check memory cache first
        if let cached = ImageCache.shared.image(for: key) {
            uiImage = cached
            return
        }
        
        isLoading = true
        
        // Use URLSession with default URLCache (disk cache)
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        
        Task.detached(priority: .userInitiated) {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let downloaded = UIImage(data: data) else { return }
                
                // Store in memory cache
                ImageCache.shared.setImage(downloaded, for: key)
                
                await MainActor.run {
                    uiImage = downloaded
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}
