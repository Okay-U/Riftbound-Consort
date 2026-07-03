import SwiftUI
#if canImport(UIKit)
import UIKit

// Process-wide cache so a cell that scrolls off and back on returns instantly
// instead of restarting the download. iOS only — on Android, SkipUI's
// AsyncImage is backed by Coil, which caches on its own.
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
#endif

struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    #if os(Android)
    var body: some View {
        AsyncImage(url: url) { image in
            content(image)
        } placeholder: {
            placeholder()
        }
    }
    #else
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
    #endif
}
