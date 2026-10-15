import UIKit

/// Async sprite loader with URL-level caching. Shared across all sprite
/// surfaces (grid, detail, battle, items) via `AppContainer.spriteLoader`.
protocol SpriteLoading: Sendable {
    /// Load a sprite from a remote URL string, returning a cached hit instantly.
    func spriteImage(from urlString: String) async -> UIImage?
}

/// A `struct`, not an actor: its caches are thread-safe (`URLSession` and
/// `URLCache` for the downloads, `NSCache` for decoded images), so
/// concurrent loads from many grid cells fetch and decode in parallel off
/// the main thread rather than queueing behind a single actor.
///
/// Decoded images are kept in memory, so a cell scrolling back into view
/// doesn't decode its sprite again.
struct SpriteLoader: SpriteLoading {
    private let session: URLSession
    private let cache: URLCache
    private let images = DecodedImageCache()

    init(session: URLSession = .shared, cache: URLCache = .shared) {
        self.session = session
        self.cache = cache
    }

    /// `@concurrent`: the cache lookup, fetch, and decode never run on the
    /// calling view's main actor.
    @concurrent
    func spriteImage(from urlString: String) async -> UIImage? {
        if let image = images[urlString] { return image }
        return await Task { await load(urlString) }.value
    }
}

// MARK: - Private
private extension SpriteLoader {
    @concurrent
    func load(_ urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        let request = URLRequest(url: url)

        let data: Data
        if let cachedResponse = cache.cachedResponse(for: request) {
            data = cachedResponse.data
        } else {
            do {
                let (fetched, response) = try await session.data(for: request)
                cache.cache(response: response, withData: fetched, for: request)
                data = fetched
            } catch {
                return nil
            }
        }
        let image = await Self.decode(data)
        if let image { images[urlString] = image }
        return image
    }

    /// Decode and pre-render the bitmap off the main thread so the first
    /// draw doesn't pay the decompression cost during scrolling.
    @concurrent
    private static func decode(_ data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return await image.byPreparingForDisplay() ?? image
    }
}

/// Decoded sprites by URL. `NSCache` is thread-safe and evicts under memory
/// pressure.
private final class DecodedImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    subscript(key: String) -> UIImage? {
        get { cache.object(forKey: key as NSString) }
        set {
            if let newValue { cache.setObject(newValue, forKey: key as NSString) }
            else { cache.removeObject(forKey: key as NSString) }
        }
    }
}

private extension URLCache {
    /// Store only successful responses, so a transient 404/5xx isn't served
    /// from cache on the next request.
    func cache(response: URLResponse, withData data: Data, for request: URLRequest) {
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            return
        }
        let cached = CachedURLResponse(response: response, data: data)
        storeCachedResponse(cached, for: request)
    }
}
