import Foundation
import SwiftData

/// Root of a recursive evolution tree from `/evolution-chain/{id}`.
struct EvolutionChain: Codable, Sendable {
    let chain: EvolutionLink
}

/// SwiftData-backed cache of one evolution chain response.
@Model
final class EvolutionChainEntity {
    @Attribute(.unique) var chainId: String
    var payload: Data

    init(chainId: String, payload: Data) {
        self.chainId = chainId
        self.payload = payload
    }
}

/// Sendable snapshot of one freshly fetched chain. Crosses actor boundaries;
/// the consumer rehydrates it into an `EvolutionChainEntity` for storage.
struct EvolutionChainPayload: Sendable {
    let chainId: String
    let payload: Data
}

/// One node in the evolution tree pointing at a species with trigger details.
struct EvolutionLink: Codable, Sendable {
    let species: SpeciesRef
    let evolvesTo: [EvolutionLink]
    let evolutionDetails: [EvolutionDetail]
}

/// Trigger metadata for an evolution edge (level, item, friendship, etc.).
struct EvolutionDetail: Codable, Sendable {
    let minLevel: Int?
    let trigger: SpeciesRef?
    let item: SpeciesRef?
    let heldItem: SpeciesRef?
    let timeOfDay: String?
    let minHappiness: Int?

    /// Display-ready trigger label, e.g. "Lv 16", "Thunder Stone", "Friendship".
    var triggerLabel: String? {
        if let level = minLevel {
            return "Lv \(level)"
        }
        if let item = item?.name {
            return item.pretty
        }
        if let trigger = trigger?.name, trigger != "level-up" {
            return trigger.pretty
        }
        if (minHappiness ?? 0) > 0 {
            return "Friendship"
        }
        return nil
    }
}

/// Name + URL reference to a species with a parsed id from the URL path.
struct SpeciesRef: Codable, Sendable, Hashable {
    let name: String
    let url: String?

    /// Display-ready name, e.g. "Pikachu".
    var displayName: String { name.capitalized }

    var id: Int? {
        guard let url, let last = URL(string: url)?
            .pathComponents.last(where: { !$0.isEmpty && $0 != "/" }),
              let n = Int(last)
        else { return nil }
        return n
    }
}

extension EvolutionChain {
    struct Stage: Identifiable, Sendable {
        let species: SpeciesRef
        let trigger: EvolutionDetail?
        var id: String { species.name }
    }

    var stages: [Stage] {
        var out: [Stage] = [Stage(species: chain.species, trigger: nil)]
        var node = chain
        while let next = node.evolvesTo.first {
            out.append(Stage(species: next.species, trigger: next.evolutionDetails.first))
            node = next
        }
        return out
    }
}
