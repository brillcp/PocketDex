import SwiftData

/// Persisted `{ name, url }` reference (ability, type, stat, item category).
/// Network payloads decode into the Sendable `APIRef` instead.
@Model
final class APIItem {
    var name: String
    var url: String

    init(name: String, url: String) {
        self.name = name
        self.url = url
    }

    convenience init(_ ref: APIRef) {
        self.init(name: ref.name, url: ref.url)
    }
}
