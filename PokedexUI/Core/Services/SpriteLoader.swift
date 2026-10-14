import UIKit

/// Async sprite loader with URL-level caching. Shared across all sprite
/// surfaces (grid, detail, battle, items) via `AppContainer.spriteLoader`.
protocol SpriteLoading: Sendable {
    /// Load a sprite from a remote URL string, returning a cached hit instantly.
    func spriteImage(from urlString: String) async -> UIImage?
}

/// A `struct`, not an actor: it holds no mutable state of its own
/// (`URLSession` and `URLCache` are thread-safe and do the caching), so
/// concurrent loads from many grid cells fetch and decode in parallel off
/// the main thread rather than queueing behind a single actor.
struct SpriteLoader: SpriteLoading {
    private let session: URLSession
    private let cache: URLCache

    init(session: URLSession = .shared, cache: URLCache = .shared) {
        self.session = session
        self.cache = cache
    }

    /// `@concurrent`: the cache lookup, fetch, and decode never run on the
    /// calling view's main actor.
    @concurrent
    func spriteImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        let request = URLRequest(url: url)

        if let cachedResponse = cache.cachedResponse(for: request) {
            return await Self.decode(cachedResponse.data)
        }

        do {
            let (data, response) = try await session.data(for: request)
            cache.cache(response: response, withData: data, for: request)
            return await Self.decode(data)
        } catch {
            return nil
        }
    }

    /// Decode and pre-render the bitmap off the main thread so the first
    /// draw doesn't pay the decompression cost during scrolling.
    @concurrent
    private static func decode(_ data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return await image.byPreparingForDisplay() ?? image
    }
}

// MARK: - Private
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
