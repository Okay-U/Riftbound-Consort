//
//  CachedRemoteImage.swift
//  Riftbound Companiokay
//

import SwiftUI
import UIKit

// Process-wide cache so a cell that scrolls off and back on returns instantly
// instead of restarting the AsyncImage download (which is what was leaving
// some gallery cells stuck on the placeholder).
actor ImageCache {
    static let shared = ImageCache()

    private let memory: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 500
        cache.totalCostLimit = 256 * 1024 * 1024
        return cache
    }()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    func image(for url: URL) async -> UIImage? {
        if let hit = memory.object(forKey: url as NSURL) { return hit }
        if let existing = inFlight[url] { return await existing.value }

        let task = Task<UIImage?, Never> {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let image = UIImage(data: data)
                else { return nil }
                return image
            } catch {
                return nil
            }
        }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        if let result {
            memory.setObject(result, forKey: url as NSURL, cost: 0)
        }
        return result
    }
}

struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var loaded: UIImage?

    var body: some View {
        Group {
            if let loaded {
                content(Image(uiImage: loaded))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else {
                loaded = nil
                return
            }
            loaded = await ImageCache.shared.image(for: url)
        }
    }
}
