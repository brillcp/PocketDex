import Foundation
import Networking

/// All PokeAPI endpoint paths.
enum Endpoint: EndpointType {
    case itemDetails(String)
    case pokemonDetails(String)
    case pokemonSpecies(String)
    case pokemon
    case items
    case evolutionChain(String)

    var path: String {
        switch self {
            case .itemDetails(let id): "item/\(id)"
            case .pokemonDetails(let id): "pokemon/\(id)"
            case .pokemonSpecies(let id): "pokemon-species/\(id)"
            case .pokemon: "pokemon"
            case .items: "item"
            case .evolutionChain(let id): "evolution-chain/\(id)"
        }
    }
}

/// All PokeAPI requests used by the app.
enum PokeAPIRequest: Requestable {
    case pokemonList(limit: Int)
    case pokemonDetails(String)
    case pokemonSpecies(String)
    case itemList(limit: Int)
    case itemDetails(String)
    case evolutionChain(String)

    var encoding: Request.Encoding { .query }
    var httpMethod: HTTP.Method { .get }

    var endpoint: EndpointType {
        switch self {
            case .pokemonList: Endpoint.pokemon
            case .pokemonDetails(let id): Endpoint.pokemonDetails(id)
            case .pokemonSpecies(let id): Endpoint.pokemonSpecies(id)
            case .itemList: Endpoint.items
            case .itemDetails(let id): Endpoint.itemDetails(id)
            case .evolutionChain(let id): Endpoint.evolutionChain(id)
        }
    }

    var parameters: HTTP.Parameters {
        switch self {
            case .pokemonList(let limit), .itemList(let limit): ["limit": "\(limit)"]
            default: HTTP.Parameters()
        }
    }
}

/// Thin client over `Network.Service`. Fetches raw bytes through the
/// service actor and decodes on the caller's task, so concurrent detail
/// requests decode in parallel on the cooperative pool instead of queueing
/// behind the service actor.
struct PokeAPIClient: Sendable {
    private let service: Network.Service

    init(service: Network.Service = .pokeAPI) {
        self.service = service
    }

    /// `@concurrent`: JSON decoding always runs on the cooperative pool,
    /// never on the caller's actor (including the main actor).
    @concurrent
    func fetch<T: Decodable & Sendable>(_ request: PokeAPIRequest, as type: T.Type = T.self) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await fetchData(request))
    }

    func fetchData(_ request: PokeAPIRequest) async throws -> Data {
        try await service.data(request)
    }

    /// Fetch a list endpoint, then every detail record it references
    /// concurrently. `onTick` fires once per detail response.
    @concurrent
    func fetchAll<T: Decodable & Sendable>(
        _ type: T.Type,
        list: PokeAPIRequest,
        detail: @escaping @Sendable (String) -> PokeAPIRequest,
        onTick: (@Sendable () async -> Void)? = nil
    ) async throws -> [T] {
        let index: APIListResponse = try await fetch(list)
        return try await withThrowingTaskGroup(of: T.self) { group in
            for ref in index.results {
                guard let id = URL(string: ref.url)?.lastPathComponent else { continue }
                group.addTask { try await fetch(detail(id), as: T.self) }
            }
            var collected: [T] = []
            collected.reserveCapacity(index.results.count)
            for try await item in group {
                collected.append(item)
                await onTick?()
            }
            return collected
        }
    }
}

extension Network.Service {
    static let pokeAPI: Network.Service = {
        let url = URL(string: "https://pokeapi.co/api/v2/")!
        return Network.Service(server: .basic(baseURL: url), logger: SilentNetworkLogger())
    }()
}

/// No-op network logger that suppresses all request/response output.
struct SilentNetworkLogger: NetworkLoggerProtocol {
    func logRequest(_ request: URLRequest) {}
    func logResponse(_ data: Data, _ response: URLResponse, printJSON: Bool) {}
}
