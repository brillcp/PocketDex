![icon](https://github.com/user-attachments/assets/1fce965f-9324-485a-8287-ff49827fc5e3)

![swift](https://img.shields.io/badge/Swift-5.0-green)
![release](https://img.shields.io/github/v/release/brillcp/PocketDex)
![platforms](https://img.shields.io/badge/Platforms-iOS%2026%2B-blue)
![apple-intelligence](https://img.shields.io/badge/Apple%20Intelligence-FoundationModels-purple)
[![spm](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-green)](#swift-package-manager)
[![license](https://img.shields.io/github/license/brillcp/PocketDex)](/LICENSE)
![stars](https://img.shields.io/github/stars/brillcp/PocketDex?style=social)

# PocketDex+

PocketDex+ is a SwiftUI app built on top of the [PokeAPI](https://pokeapi.co), with a working turn-based Pokemon battle mode driven by **Apple's on-device FoundationModels framework** and **local multiplayer** over MultipeerConnectivity. Browse the dex, dig into a pokemon, pick a fight against AI or a friend nearby.

If you're a senior iOS engineer looking for a worked example of modern SwiftUI patterns (actors, `@Observable`, SwiftData, on-device AI, MultipeerConnectivity), or someone earlier in their iOS journey trying to see how these pieces fit together in a real app, hopefully there's something here for you. Every feature is small enough to read end-to-end, and every public type plus every protocol member carries a doc comment explaining why it exists.

Built by [Viktor Gidlöf](https://viktorgidlof.com).

<img height="800" alt="Pokedex+" src="https://github.com/user-attachments/assets/c9f1df1d-bca8-40db-b57a-0059c7429c65" />

---

# Architecture 🏛

PocketDex+ is **Protocol-Oriented MVVM** with clear layer boundaries and aggressive actor isolation.

## Key architectural benefits

- ✅ **Protocol-Oriented**: every layer depends on abstractions, enabling DI and easy testing.
- ✅ **Generic Networking**: one `APIService<Config>` actor over a `Requestable` protocol drives every PokeAPI endpoint.
- ✅ **Storage-First**: SwiftData is the source of truth; the network is a backfill mechanism.
- ✅ **Actor-Based Concurrency**: every long-lived worker is an actor; SwiftUI-bound types are `@MainActor @Observable`.
- ✅ **Clean Separation**: App / Features / Core / DesignSystem layers with one-way dependencies (App can see everything, Core depends on nothing).
- ✅ **Type Safety**: generics, Sendable AI snapshots crossing actor boundaries, `@Attribute(.unique)` on every keyed cache entity (Pokemon by id, EvolutionChainEntity by chainId). Nested rows ride on cascade; `ItemData` is keyed by category title. Move and type data live in PokeBattleKit's own disk cache.
- ✅ **Reactive UI**: SwiftUI body re-renders driven entirely by `@Observable` view models.
- ✅ **On-Device AI**: Apple `FoundationModels` with `@Generable` structured output, `Tool`-based type/damage reasoning, and deterministic fallbacks via [PokeBattleKit](https://github.com/brillcp/PokeBattleKit) at every call site.
- ✅ **Local Multiplayer**: host-authoritative architecture with a typed `Codable` message protocol over MultipeerConnectivity. The same `BattleViewModelProtocol` drives both AI and peer-to-peer battles with zero view changes.

### SOLID Compliance Score: 0.94 / 1.0

- **S**ingle Responsibility: each service, prefetcher, and view model has one job. View models are thin conductors that delegate timing, formatting, and strategy to dedicated collaborators. Shared UI components each own a single reusable concern.
- **O**pen/Closed: the `APIService<Config>` generic + `Requestable` protocol lets new endpoints slot in without modifying the network layer. `BattleViewModelProtocol` let an entirely new battle mode ship without touching the battle view, animator, or log formatter.
- **L**iskov Substitution: every service is reached through its protocol on `AppContainer`, so previews and tests can swap any concrete type for a mock without touching call sites. Multiple conformers of the same protocol are interchangeable at runtime.
- **I**nterface Segregation: each view model exposes only the surface its view needs. No god-protocol shared across consumers.
- **D**ependency Inversion: `AppContainer` is the single composition root. Views read services via `@Environment(\.container)`. No `static let shared` lookups in feature code.

```
┌─────────────────────────────────────────────────────────┐
│  App/                                                   │
│    PokedexUIApp        AppContainer (composition root)  │
├─────────────────────────────────────────────────────────┤
│  Features/                                              │
│    Pokedex   PokemonDetail   Battle   Search            │
│    Bookmarks  Items  Multiplayer                        │
├─────────────────────────────────────────────────────────┤
│  Core/                                                  │
│    Domain/  (SwiftData @Models)                         │
│    Services/  (actor-backed networking and prefetchers) │
│    Storage/  (DataStorageReader @ModelActor)            │
│    Networking/  (APIService<Config> generic actor)      │
├─────────────────────────────────────────────────────────┤
│  DesignSystem/                                          │
│    Components/  Colors/  Modifiers/  Fonts              │
└─────────────────────────────────────────────────────────┘
```

## Concurrency model

Every long-lived worker is an actor unless it has to bind to SwiftUI directly:

| Type                       | Isolation                  | Why                                                          |
| -------------------------- | -------------------------- | ------------------------------------------------------------ |
| `BattleAIService`          | `actor`                    | Owns the `LanguageModelClient`, called from any context      |
| `SpriteLoader`             | `actor`                    | Image download + `URLCache` access                           |
| `ImageColorAnalyzer`       | `actor`                    | Pixel-scan pipeline, off the main thread                     |
| `AudioPlayer`              | `actor`                    | AVFoundation playback                                        |
| `EvolutionService`         | `actor`                    | Process-wide chain-id memo                                   |
| `DataStorageReader`        | `@ModelActor`              | Isolated SwiftData `ModelContext`                             |
| `APIService<Config>`       | `actor`                    | Generic network actor over `Requestable`                     |
| `MultipeerService`         | `@Observable`              | MC delegate callbacks are `nonisolated`, hop to `@MainActor` inline only when mutating observable state |
| `BattleAnimator`           | `@MainActor @Observable`   | Owns cue mutation + `withAnimation` blocks for the arena     |
| View models                | `@MainActor @Observable`   | SwiftUI binding                                              |

The type chart lives in PokeBattleKit as a `Sendable` value type (`TypeChart`), initialized once at app launch via `PokeBattleKit.initialize()`. Views and AI read it through `PokeBattleKit.typeChart` with zero actor hops. `BattleEngine` is also a plain `Sendable` struct in PokeBattleKit, used on the main actor inside `BattleViewModel` but not isolated itself.

## Dependency injection

A single `AppContainer` is the composition root. Every service, prefetcher, and long-lived worker is constructed there and handed to the view tree through one environment key:

```swift
@MainActor
final class AppContainer {
    let pokemonService:     PokemonServiceProtocol
    let evolutionService:   EvolutionServiceProtocol
    let itemService:        ItemServiceProtocol
    let spriteLoader:       SpriteLoading
    let imageColorAnalyzer: ImageColorAnalyzing
    let audioPlayer:        AudioPlaying
    let battleAI:           BattleAIServiceProtocol
    let multipeerService:   MultipeerService
    static let live = AppContainer()
}

@Environment(\.container) private var container
```

Tests and previews swap in a custom container with mocks; the rest of the app is unaware.

## Storage

Three top-level `@Model` types, each deduped on a unique key. Nested rows (stats, abilities, sprites, etc.) live under their parent and ride on cascade delete.

- `Pokemon` (id-unique): full hydrated detail, stats, sprites, moves, species fields, bookmark flag
- `ItemData` (title-keyed): item catalogue bucketed by category title
- `EvolutionChainEntity` (chainId-unique): evolution chain rows keyed by chain id

Move and type effectiveness data are owned by PokeBattleKit, which caches them as JSON files on disk via its own `DiskCache`. The pokedex grid renders from `Pokemon` rows; full hydration runs once at app launch and is cached forever, since Pokemon data is immutable.

---

# Battle System ⚔️

The battle screen is a turn-based 1v1 simulator built on top of the real PokeAPI move and type data. Both sides commit to 4 hand-picked moves before the fight starts, then trade turns until one side faints. The Gen-V damage formula drives every hit (level 50, STAB, type effectiveness, crit roll, accuracy roll, burn penalty), and status effects (paralysis, burn, poison) tick at end-of-turn.

The opponent is driven entirely by **Apple's `FoundationModels` framework**, running fully on-device.

## What the AI does

PocketDex+ uses `SystemLanguageModel.default` with **structured generation** (`@Generable`) and **tool use** (`Tool` protocol) for three decisions:

1. **Opponent picking** ("Random" button in the picker sheet)
   The model receives the player's name, types, and BST plus a shuffled roster of up to 50 pre-filtered candidates with matchup annotations. It returns a structured `OpponentPickResult` with the chosen index.
2. **Loadout selection** (background task during the loadout screen)
   The model receives both combatants' typings and a shortlisted move pool. It can call `checkTypeEffectiveness` and `estimateDamage` tools to reason about coverage before returning a `LoadoutPickResult` with four move names.
3. **Per-turn move selection** (every time the player commits a move)
   The model receives both combatants' current HP, status, types, and the opponent's four moves. It can call `estimateDamage` to compare options and detect KOs, then returns a `MovePickResult` with the chosen move name.

Every call degrades gracefully to deterministic heuristics (in [PokeBattleKit](https://github.com/brillcp/PokeBattleKit)) if Apple Intelligence is unavailable, the session is busy, or the model returns an unresolvable result. **The battle UI never blocks waiting on a model response.**

## Structured generation and tools

Each AI decision uses `@Generable` structs for type-safe output instead of free-text parsing. The model returns typed results (`MovePickResult`, `LoadoutPickResult`, `OpponentPickResult`) that resolve directly to game objects by name or index lookup.

Two `Tool` conformances give the model access to game data it can't derive from training:

- **`CheckTypeTool`**: wraps the type chart to report effectiveness multipliers for any attacking type vs defending types.
- **`EstimateDamageTool`**: wraps the Gen-V damage calculator to return estimated damage, defender HP, and whether the hit would KO.

System instructions live in [`PokedexUI/Features/Battle/AI/LLMInstructions/`](PokedexUI/Features/Battle/AI/LLMInstructions/), split per task. Each is a single short paragraph guiding tool usage and tactical priorities.

## Deterministic strategy layer

The scoring, filtering, and post-pick correction logic lives in [PokeBattleKit](https://github.com/brillcp/PokeBattleKit) as pure deterministic code with no LLM dependency:

- **`MoveScoring`**: in-battle and loadout scoring with STAB, type effectiveness, priority, and escalating recency penalties to prevent move spamming.
- **`MoveStrategy`**: heuristic fallback pick and post-pick adjustments (immune repair, phase-aware switching, KO override, status redundancy).
- **`LoadoutStrategy`**: shortlisting, heuristic 4-move selection, fill (pad LLM partial picks to 4), and mild fairness handicapping.
- **`OpponentStrategy`**: BST-tolerant pool filtering, mutual-threat scoring, and heuristic best-opponent ranking.

Every `BattleAIService` method follows the same shape: PokeBattleKit computes a heuristic fallback, the LLM attempts a smarter pick via structured generation with tools, then PokeBattleKit runs post-pick corrections on whichever branch won.

## Tuning the AI

All scoring weights live in `MoveScoring.Weights` inside PokeBattleKit. They're public static properties, so you can read (and fork) them to experiment with AI behavior:

| Weight group | What it controls | Examples |
| --- | --- | --- |
| **Damage** | How much the AI values raw damage, KO potential, resisted hits | `koBonus` (55), `nearKOBonus` (18), `resistedMult` (0.4) |
| **Status** | Value of inflicting paralysis, burn, poison, sleep | `paralysisFaster` (28), `burnPhysical` (24), `sleep` (22) |
| **Stat changes** | Boost/debuff desirability based on matchup context | `statBoostMatching` (10), `statBoostSpeedSlow` (16) |
| **Recency** | Escalating penalties for repeating the same move | `repeatFirst` (18), `repeatSecond` (40), `repeatThird` (65) |
| **Low HP** | Survival instinct: healing and priority at low health | `lowHPHealBonus` (35), `lowHPPriorityBonus` (6) |

Raising `koBonus` makes the AI more aggressive. Lowering the recency penalties lets it spam its best move. Bumping `lowHPHealBonus` makes it play safer when hurt. The heuristic fallback and LLM post-pick adjustments both flow through these weights, so a single change affects both code paths.

## Why on-device?

- **Zero latency to the network**: every inference happens locally.
- **Free**: no API tokens, no rate limits.
- **Private**: battle state never leaves the device.
- **Available offline**: the app stays playable once the PokeAPI data is cached.

This is the kind of feature `FoundationModels` was built for: small, structured, latency-sensitive decisions on top of well-defined data.

---

# Local Multiplayer 🏟

Both players open the Gym tab, which advertises and browses simultaneously. Nearby trainers appear in a discovery list; tapping one sends an invite. Once both accept, each picks a Pokemon and four moves, then the battle begins. All communication is peer-to-peer over Wi-Fi or Bluetooth via MultipeerConnectivity. No servers, no accounts, no internet required.

## Authority model

**Host-authoritative.** The MC advertiser is the host; the browser is the guest. Only the host runs `BattleEngine`. The guest sends its move choice, receives resolved events, and renders them. This eliminates desync from random rolls (crits, accuracy, status chance).

## Message protocol

A single `Codable` enum (`BattleMessage`) covers the full lifecycle:

| Phase | Messages | What crosses the wire |
| --- | --- | --- |
| Handshake | `.hello`, `.challengeProposed`, `.challengeAccepted`, `.challengeDeclined` | Protocol version, `PokemonSummary` (id, name, sprites, types, stats), 4 move names |
| Battle | `.moveCommitted`, `.roundResolved`, `.battleEnded` | Move name + turn number, resolved `[Event]` array, winner side |
| Session | `.rematch`, `.disconnect` | Control signals only |

Move names resolve locally via `PokeBattleKit.move(named:)`. Full `Move` objects never cross the wire. Both devices share the same move database from `PokeBattleKit.initialize()`.

## Turn synchronization

Commit-collect-resolve pattern with no races:

1. Both players see the move grid
2. Player taps a move, sends `.moveCommitted(name, turnN)` to peer
3. **Host collects**: stores own move + guest's move. When both present for turn N, runs `engine.resolveRound()`, sends `.roundResolved(events, N)` to guest
4. **Guest receives**: applies events to local state, animates via `BattleAnimator`
5. Both reset for turn N+1

The guest reverses `.player`/`.opponent` in received events via `side.opposite` before rendering. `turnNumber` on every message prevents stale/duplicate processing.

## Key design decisions

- **Separate VM, not branching**: `MultiplayerBattleViewModel` conforms to `BattleViewModelProtocol` alongside `BattleViewModel`. `BattleView` renders either without knowing which one it has.
- **Shared components**: `PokemonPickerGrid`, `PokemonSpriteCard`, `MoveLoadoutView`, `MovePickerGrid`, and `MoveSelection` (observable selection state class) are used by both single-player and multiplayer flows. `BattleStateReducer` handles state mutation for both battle VMs. Screen-level orchestration stays separate.
- **Rematch reuses MC session**: no need to re-discover. Just exchange new `ChallengePayload`s.

---

# Battle UX flow 🎮

### Single-player (AI)

```
Detail view
   │ (tap Fight)
   ▼
Opponent picker sheet  <-- Random (AI)
   │ (tap a candidate)
   ▼
Loadout screen
   │ - Hydrate both pokemon (cache or network)
   │ - AI picks opponent's 4 from full movepool (background task)
   │ - Player hand-picks own 4 from sorted movepool
   │ (tap Battle)
   ▼
Battle view
   - Arena renders frame 1 (state built in init)
   - Each turn: player taps move ->
       AI picks opponent's move ->
       Engine resolves both in speed order ->
       Events animate (lunge, shake, damage, faint)
```

The battle screen never holds the loadout sheet open: every preflight task either completes before the player commits, or runs lazily inside the battle view itself. The move grid is disabled while the AI resolves the opponent's pick so the player can't double-tap into a stale turn.

### Multiplayer (Gym)

```
Gym tab
   │ (advertise + browse simultaneously)
   ▼
Discovery list
   │ (tap a nearby trainer)
   ▼
Invitation alert on peer device
   │ (accept)
   ▼
Pick your fighter (PokemonPickerGrid)
   │ (tap a pokemon)
   ▼
Pick moves (MoveLoadoutView)
   │ - Player picks 4 moves
   │ - Sends ChallengePayload to peer
   │ - "Waiting for opponent..." until peer submits
   │ (both ready)
   ▼
Battle view
   - Same BattleView, driven by MultiplayerBattleViewModel
   - Moves committed over MC, host resolves, guest renders events
```

---

# Data loading 📥

Background workers fill the on-disk cache at app launch so the UI never waits on the network.

| Worker                  | What it pulls                             | When             |
| ----------------------- | ----------------------------------------- | ---------------- |
| `PokeBattleKit`         | Type chart (18 type damage relations) + full move catalogue | App launch via `PokeBattleKit.initialize()` |
| `PokemonService`        | Full pokedex hydration (detail + species)  | App launch       |
| `EvolutionService`      | Evolution chains for hydrated pokemon     | App launch, background priority |

Sprite colors are resolved lazily on first display through `ImageColorAnalyzer` (an actor) and cached in-process by pokemon id, so a detail view that opens the same pokemon twice runs the pixel scan once. The pokedex grid pulls the full `/pokemon?limit=1150` index in a single request, then fans out detail + species fetches concurrently with progress ticks. Subsequent app launches read everything from SwiftData with zero network calls.

---

# Design System 🎨

Pixel font, gameboy-style aesthetic, glass effects:

- **`Chip`**: small inline pill used for type tags, generation badges, status pills, effectiveness markers. Always a 4-point corner radius (capsules look too modern next to the pixel font).
- **`MoveCell`**: shared between the battle move grid and the loadout move picker, switched via a `Mode` enum.
- **`TypeColor`**: centralized type-to-color map used by every move chip, type tag, and weakness grid row.
- **`PokemonGrid<Cell>`**: generic grid taking a `GridLayout` and a `@ViewBuilder` cell closure. Handles only scrolling and layout; navigation, search, and overlays are the caller's responsibility.
- **`PokedexGridView`**: wraps `PokemonGrid` with color-analyzed cells (dominant-color backgrounds via `ImageColorAnalyzer`), `NavigationLink` routing, and a loading overlay. Toggleable between 3 and 4 columns.
- **`PokemonSpriteCard`**: sprite-over-name grid cell with type chips. Used by search results, bookmarks, type lists, opponent picker, and multiplayer fighter picker.
- **`PokemonPickerGrid`**: wraps `PokemonGrid` with a toolbar search bar and cached haystack filtering (name, type, genus, habitat, legendary/mythical, abilities). Used by opponent picker, multiplayer fighter picker, and bookmarks.
- **`GridLayout`**: single source of truth for grid column counts and spacing across the app (`.two`, `.three`, `.four`).
- **`MoveLoadoutView`**: pokemon summary card + `MovePickerGrid` + caller-provided bottom bar slot. Shared across single-player and multiplayer move selection.
- **`MovePickerGrid`**: 2-column move grid with toggle selection and optional type effectiveness annotations.

---

# Dependencies 🔗

| Package | What it does |
| --- | --- |
| [Networking](https://github.com/brillcp/Networking) | Thin actor-based `URLSession` wrapper with a generic `Requestable` protocol driving every PokeAPI endpoint |
| [PokeBattleKit](https://github.com/brillcp/PokeBattleKit) | Standalone battle engine: damage calculator, type chart, move/combatant models, and deterministic AI strategies (scoring, heuristics, adjustments) |

```swift
dependencies: [
    .package(url: "https://github.com/brillcp/Networking.git", .upToNextMajor(from: "0.10.0")),
    .package(url: "https://github.com/brillcp/PokeBattleKit.git", .upToNextMinor(from: "0.1.1"))
]
```

---

# Requirements ❗️

- Xcode 26+
- iOS 26+ (for the `FoundationModels` framework, `@Observable`, SwiftData)
- Swift 5 language mode
- Apple Intelligence enabled on the device for the AI features (graceful fallback to deterministic heuristics on devices without it)
- Local Network permission for multiplayer (prompted automatically on first Gym use)
