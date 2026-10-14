import FoundationModels

// MARK: - Generable Results

// Output schemas for guided generation. The model is constrained to fill
// these structs (no free-form text to parse) and has no `Tool`s to call:
// everything it needs is already in the prompt. Names and indices it returns
// are still validated against the real options before use.

/// Structured reply for an in-battle move pick. `moveName` is looked up in the
/// attacker's loadout; an unknown name falls back to the heuristic pick.
@Generable(description: "The chosen move for this turn")
struct MovePickResult {
    @Guide(description: "Exact move name from the available list, e.g. 'thunderbolt'")
    var moveName: String
}

/// Structured reply for the AI's four-move loadout. Unknown names are dropped
/// and the remainder is topped up to four by `LoadoutStrategy.fill`.
@Generable(description: "Four moves for the battle loadout")
struct LoadoutPickResult {
    @Guide(description: "Exactly 4 move names from the available list")
    var moveNames: [String]
}

/// Structured reply for opponent matchmaking: a 1-based index into the
/// shuffled roster built by `OpponentPrompt`, mapped back to a Pokémon id.
@Generable(description: "The chosen opponent for this battle")
struct OpponentPickResult {
    @Guide(description: "The number of the chosen opponent from the list")
    var index: Int
}
