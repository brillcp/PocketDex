![icon](https://github.com/user-attachments/assets/7d057934-8477-4afc-9c3f-e29973103a0b)

![swift](https://img.shields.io/badge/Swift-6-orange)
![release](https://img.shields.io/github/v/release/brillcp/PocketDex)
![platforms](https://img.shields.io/badge/Platforms-iOS%2026%2B-blue)
[![spm](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-green)](#dependencies-)
[![license](https://img.shields.io/github/license/brillcp/PocketDex)](/LICENSE)
![stars](https://img.shields.io/github/stars/brillcp/PocketDex?style=social)

# PocketDex+

PocketDex+ is a SwiftUI app built on top of the [PokeAPI](https://pokeapi.co), with a working turn-based Pokemon battle mode against a **simulation-tested rule-based AI** and **local multiplayer** over MultipeerConnectivity. Browse the dex, dig into a pokemon, pick a fight against AI or a friend nearby.

If you're a senior iOS engineer looking for a worked example of modern SwiftUI patterns (**Swift 6 strict concurrency**, actors, `@Observable`, SwiftData with a background `@ModelActor`, a rule-based battle AI checked by whole-Pokédex simulation, MultipeerConnectivity), or someone earlier in their iOS journey trying to see how these pieces fit together in a real app, hopefully there's something here for you. Every feature is small enough to read end-to-end, and the code is commented to explain *why* things are built the way they are: data flow, threading choices, and the non-obvious decisions.

Built by [Viktor Gidlöf](https://viktorgidlof.com).

<img height="800" alt="Pokedex+" src="https://github.com/user-attachments/assets/c9f1df1d-bca8-40db-b57a-0059c7429c65" />

---

# Architecture 🏛

PocketDex+ is **Protocol-Oriented MVVM** with clear layer boundaries and **Swift 6 data-race safety** enforced by the compiler.

## Key architectural benefits

- ✅ **Swift 6 language mode**: full compile-time data-race checking, with zero warnings. See [Concurrency model](#concurrency-model).
- ✅ **Protocol-Oriented**: every layer depends on abstractions, enabling DI and easy testing.
- ✅ **Background data pipeline**: network JSON decodes into `Sendable` DTOs in parallel off the main thread; a `@ModelActor` turns them into SwiftData rows. `@Model` objects never cross actors.
- ✅ **Storage-First**: SwiftData is the source of truth; the network is a one-time backfill mechanism.
- ✅ **Clean Separation**: App / Features / Core / DesignSystem layers with one-way dependencies (App can see everything, Core depends on nothing).
- ✅ **Type Safety**: generics, `Sendable` snapshots crossing actor boundaries (`PokemonSearchEntry`, `Candidate`, DTOs), `@Attribute(.unique)` on every keyed cache entity (Pokemon by id, EvolutionChainEntity by chainId). Move and type data live in PokeBattleKit's own disk cache.
- ✅ **Reactive UI**: SwiftUI body re-renders driven entirely by `@Observable` view models, with views split so high-frequency updates only touch the views that read them.
- ✅ **Adaptive layout**: size-class driven, so the app works on iPhone, iPad, resizable windows, and the foldable iPhone Duo (detail on the left, grid on the right when unfolded).
- ✅ **Battle AI**: rule-based AI from [PokeBattleKit](https://github.com/brillcp/PokeBattleKit), with opponents matched by simulated strength ratings and three difficulty levels.
- ✅ **Local Multiplayer**: host-authoritative architecture with a typed, versioned `Codable` message protocol over MultipeerConnectivity. The same `BattleViewModelProtocol` drives both AI and peer-to-peer battles with zero view changes.

### SOLID Compliance Score: 0.94 / 1.0

- **S**ingle Responsibility: each service, store, and view model has one job. View models are thin conductors that delegate timing, formatting, and strategy to dedicated collaborators. Shared UI components each own a single reusable concern.
- **O**pen/Closed: new endpoints are a new `PokeAPIRequest` case plus a `Sendable` DTO; the client, decoding, and storage pipeline don't change. `BattleViewModelProtocol` let an entirely new battle mode ship without touching the battle view, animator, or log formatter.
- **L**iskov Substitution: every service is reached through its protocol on `AppContainer`, so previews and tests can swap any concrete type for a mock without touching call sites. Multiple conformers of the same protocol are interchangeable at runtime.
- **I**nterface Segregation: each view model exposes only the surface its view needs. No god-protocol shared across consumers.
- **D**ependency Inversion: `AppContainer` is the single composition root. Views read services via `@Environment(\.container)`. No `static let shared` lookups in feature code.

```
┌──────────────────────────────────────────────────────────────┐
│  App/                                                        │
│    PokedexUIApp     AppContainer (composition root)          │
│    EnvironmentValues/  (@Entry var container)                │
├──────────────────────────────────────────────────────────────┤
│  Features/                                                   │
│    Pokedex   PokemonDetail   Battle   Search                 │
│    Bookmarks  Items  Multiplayer                             │
├──────────────────────────────────────────────────────────────┤
│  Core/                                                       │
│    Models/      SwiftData @Model classes                     │
│    DTOs/        Sendable Decodable network payloads          │
│    Networking/  PokeAPIClient, endpoints, JSON coders        │
│    Storage/     PokedexStore (@ModelActor)                   │
│    Services/    repository, evolution, sprites, color,       │
│                 audio, Multipeer/                            │
├──────────────────────────────────────────────────────────────┤
│  DesignSystem/                                               │
│    Components/  Colors/  Spacing  Fonts  View modifiers      │
└──────────────────────────────────────────────────────────────┘
```

## Project structure

```
PokedexUI/
├── App/
│   ├── PokedexUIApp.swift          App entry, installs the shared ModelContainer
│   ├── AppContainer.swift          Composition root (Sendable), owns every service
│   └── EnvironmentValues/          @Entry var container
├── Core/
│   ├── Models/                     @Model: Pokemon, ItemData/ItemDetail, APIItem
│   ├── DTOs/                       PokemonDTO, ItemDetailDTO, PokemonSpecies, EvolutionChain
│   ├── Networking/PokeAPI.swift    Endpoints, requests, PokeAPIClient, snake_case coders
│   ├── Storage/PokedexStore.swift  Background @ModelActor: DTO -> @Model import
│   └── Services/
│       ├── PokedexRepository       First-launch download + import, progress
│       ├── EvolutionService        Memory -> SwiftData -> network chain cache
│       ├── SpriteLoader            Concurrent image fetch + decode
│       ├── ImageColorAnalyzer      Dominant sprite color, cached per pokemon
│       ├── AudioPlayer             Pokemon cries
│       └── Multipeer/              MultipeerService, BattleMessage, PokemonSummary
├── Features/
│   ├── Pokedex/                    Root tabs, grid, adaptive split layout
│   ├── PokemonDetail/              Detail screen + subviews (stats, evolutions, matchups)
│   ├── Items/  Search/  Bookmarks/
│   ├── Battle/                     BattleView, view model, animator, reducer, log
│   │   ├── AI/                     BattleAIService (PokeBattleKit's AI), BattleAIDriver
│   │   ├── Setup/                  Loadout screen
│   │   └── Subviews/
│   └── Multiplayer/                Gym lobby, peer battle view model
└── DesignSystem/
    ├── Components/                 Chip, MoveCell, PokemonGrid, PokedexGridView, ...
    ├── Colors/                     TypeColor
    └── Spacing, Font, Color, GridLayout, SortType, Tabs, View, String+Formatting
```

## Concurrency model

The app target builds in the **Swift 6 language mode** with:

| Build setting | Value | What it means |
| --- | --- | --- |
| `SWIFT_VERSION` | `6.0` | Data-race safety is checked at compile time; violations are errors, not warnings |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `nonisolated` | Code isn't main-actor unless it says so. Models and DTOs are plain `Sendable` types, no isolation annotations needed |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | `nonisolated async` functions run on the caller's actor; work that must leave the main thread is an actor or marked `@concurrent` |

UI-facing types opt in to the main actor explicitly; everything else runs in the background:

| Type | Isolation | Why |
| --- | --- | --- |
| View models, `BattleAnimator`, `MoveSelection` | `@MainActor @Observable` | SwiftUI binding |
| `PokedexRepository` | `actor` | First-launch download + import pipeline |
| `PokedexStore` | `@ModelActor` | Background SwiftData `ModelContext`; created via a `@concurrent` factory so it never binds to the main thread |
| `EvolutionService` | `actor` | In-memory chain cache in front of SwiftData and the network |
| `PokeAPIClient` | `Sendable` struct, `@concurrent` fetch | JSON decodes in parallel task-group children |
| `SpriteLoader` | `Sendable` struct, `@concurrent` | Stateless, so grid cells load and decode sprites in parallel |
| `ImageColorAnalyzer` | `actor` + `@concurrent` scan | The actor only guards the cache; pixel scans run concurrently |
| `AudioPlayer`, `BattleAIService` | `actor` | AVFoundation playback, opponent picks over the whole Pokédex off the main actor |
| `MultipeerService` | `@MainActor @Observable` | MC delegate callbacks are `nonisolated` and hop to the main queue in arrival order |
| `AppContainer` | `Sendable` | Immutable references to Sendable services, so it can be the `@Entry` environment default |

**The data flow on first launch:**

```
PokeAPI ──► PokeAPIClient (@concurrent, parallel)
              │  JSON ──► Sendable DTOs (convertFromSnakeCase)
              ▼
         PokedexRepository (actor) ── throttled progress ──► PokedexViewModel (@MainActor)
              │  DTOs
              ▼
         PokedexStore (@ModelActor) ── builds @Model rows, saves
              │
              ▼  same ModelContainer
         Main ModelContext / @Query ──► SwiftUI
```

Only `Sendable` values cross actor boundaries: DTOs, counts, raw `Data` payloads, and snapshots like `PokemonSearchEntry` (search haystacks built in the background) and PokeBattleKit's `Candidate`. SwiftData `@Model` instances stay on the context that created them.

The few escape hatches are all in `MultipeerService`, because MultipeerConnectivity isn't annotated for Swift concurrency yet: a `@preconcurrency import`, one documented `@unchecked Sendable` wrapper for the invitation callback, and a `DispatchQueue.main` hop that preserves message order.

The type chart lives in PokeBattleKit as a `Sendable` value type (`TypeChart`), initialized once at app launch via `PokeBattleKit.initialize()`. `BattleEngine` is also a plain `Sendable` struct in PokeBattleKit, used on the main actor inside `BattleViewModel` but not isolated itself.

## Dependency injection

A single `AppContainer` is the composition root. Every service and long-lived worker is constructed there and handed to the view tree through one environment key:

```swift
final class AppContainer: Sendable {
    let modelContainer:     ModelContainer
    let repository:         PokedexRepositoryProtocol
    let evolutionService:   EvolutionServiceProtocol
    let spriteLoader:       SpriteLoading
    let imageColorAnalyzer: ImageColorAnalyzing
    let audioPlayer:        AudioPlaying
    let battleAI:           BattleAIServiceProtocol
    let multipeerService:   MultipeerService
    static let live = AppContainer()
}

extension EnvironmentValues {
    @Entry var container: AppContainer = .live
}

@Environment(\.container) private var container
```

Tests and previews swap in a custom container with mocks (or an in-memory `ModelContainer` via `AppContainer.makeModelContainer(inMemory: true)`); the rest of the app is unaware.

## Storage

Three top-level `@Model` types, each deduped on a unique key. Nested rows (stats, abilities, sprites, etc.) live under their parent.

- `Pokemon` (id-unique): full hydrated detail, stats, sprites, moves, species fields, bookmark flag
- `ItemData` (title-keyed): item catalogue bucketed by category title (English effect texts only)
- `EvolutionChainEntity` (chainId-unique): evolution chains stored as their JSON payload

`@Model` classes are persistence-only: they're built from DTOs by `PokedexStore` and never decoded from JSON directly. The UI reads them through the main `ModelContext` or `@Query`; bookmarks are the only field the app writes after import.

Move and type effectiveness data are owned by PokeBattleKit, which caches them as JSON files on disk via its own `DiskCache`. Pokemon data is immutable, so full hydration runs once and is cached forever.

---

# Adaptive layout 📱

The layout follows the horizontal size class, never the device model, so it adapts live as a window resizes or the device folds:

- **Compact width** (iPhone, folded iPhone Duo): a single navigation stack; tapping a pokemon pushes its detail with a zoom transition.
- **Regular width** (unfolded iPhone Duo, iPad, wide windows): the detail sits in a leading column and the grid in a trailing column. `NavigationSplitView` always puts its sidebar on the leading edge, so the two columns are separate navigation stacks.

The open pokemon is carried across size-class changes, so folding or unfolding keeps it on screen.

---

# Battle System ⚔️

The battle screen is a turn-based 1v1 simulator built on top of the real PokeAPI move and type data. Both sides commit to up to 4 hand-picked moves before the fight starts, then trade turns until one side faints. Both sides start equal: no HP bonus, no handicap. The rules come from [PokeBattleKit](https://github.com/brillcp/PokeBattleKit) and follow the main games:

- **Level 50**: stats use the real formulas at level 50 with perfect IVs and no EVs, and the Gen-V+ damage formula drives every hit (STAB, uncapped type effectiveness so 4x weaknesses hit 4x, 1-in-24 crits, accuracy and damage rolls, burn penalty).
- **Turn order**: higher move priority goes first, then higher speed. Speed stat stages count (Agility doubles speed, Icy Wind slows), and paralysis halves it.
- **Move mechanics**: multi-hit moves (Bullet Seed hits 2-5 times), flinching (Fake Out works on the first turn only), recharge turns, and stat changes on the right side (Close Combat lowers its user's defences). Situational power follows the games: Low Kick by weight, Reversal by HP, Gyro Ball by Speed, Facade/Hex/Venoshock/Payback doubling when their condition holds, Foul Play and Body Press using the right stats, Seismic Toss and Super Fang as fixed damage. Moves the engine can't model faithfully, like confusion-only moves, are left out of the movepool.
- **Every Pokémon can battle**: a Pokémon that knows fewer than four usable moves fights with what it has, a form with almost no PokeAPI learnset (Mega, G-Max) uses its base species' moves, and a Pokémon with no usable attack gets Struggle.
- **Status effects**: burn and poison deal damage at the end of each turn (Toxic escalates), paralysis can skip a turn, sleep lasts 1-3 turns (Rest: 2), and a frozen Pokémon has a 20% chance each turn to thaw (Fire attacks thaw it at once).
- **Type immunities**: Electric types can't be paralyzed, Fire types can't be burned, Ice types can't be frozen, and Poison and Steel types can't be poisoned. Thunder Wave fails on Ground types, and a move with no effect (Body Slam into a Ghost type) can't inflict its status either.

At real level-50 HP, a one-on-one fight without switching would be over in a hit or two. So every Pokémon gets 4x its level-50 HP while each hit stays real-game size: a neutral same-type attack takes about a tenth of the target's HP and a super-effective one about a fifth, and a battle lasts around six turns. Healing, Rest, and burn and poison damage keep their real-game amounts.

The opponent is driven by [PokeBattleKit](https://github.com/brillcp/PokeBattleKit)'s rule-based AI. There's no language model: every decision is instant, works on every device, and is exactly what the package's whole-Pokédex simulation tests.

## What the AI does

1. **Fighter picking** ("Smart pick" button in the picker sheet)
   "Battle" on a Pokémon's page challenges that Pokémon; you then choose your fighter, from **My team** or everyone, grouped by generation. Every Pokémon has a **strength rating** from simulated battles (see below), and each team member is tagged Strong, Even or Weak against the opponent. A fair matchup is one you're predicted to win 35-65% of the time at equal level, with no one-sided type matchup (where one side hits super-effectively and is resisted back). "Smart pick" chooses at random among the fair fighters in your team (or among all when none is fair), favouring tense matchups (close to 50/50, both sides able to hit hard), and skips the last ten fighters it suggested against that opponent.
2. **Loadout selection** (when you lock in your moves)
   Role-based: the best attack, an attack of a different type, then a status, boost or heal move, or more coverage. On easy, the AI's strongest attack is swapped for a weaker one.
3. **Per-turn move selection**
   Every move is valued in HP of damage: attacks by the damage they'll do plus a KO bonus, boosts, statuses and heals by the damage they gain or prevent over the next few turns. It reacts to KO threats from faster opponents with priority moves. The AI only knows your moves once you've used them, as a human opponent would.

The player picks the difficulty from the gear menu at the bottom of the loadout screen; the choice is saved and passed to every AI decision. Difficulty works the classic Pokémon way: the opponent is 6 levels below you on easy, the same level on fair, and 7 levels above on hard (calibrated across the whole Pokédex so a good player wins about 90% / 50% / 20%), and the AI plays more loosely on easy and always takes its best move on hard. Levels are shown on the loadout screen and the HP cards.

## Strength ratings

Base stat total (BST) is a poor guide to how strong a Pokémon is in battle: it ignores movepools. So PokeBattleKit rates every Pokémon by simulation: each of the 1,351 Pokémon fights 80 random opponents at equal level with the AI on both sides, and the results are fitted to Elo-style ratings (a Bradley-Terry model; 1500 is average, 400 points apart is 10-to-1 odds). They ship as a 24 KB JSON file in the package (`PokemonStrength`) and predict lopsided matchups correctly about 93% of the time. Rerun the generator after changing the rules or the AI.

## Heuristic strategy layer

- **`MoveScoring`**: values every move in HP of damage, using a short forecast of the fight (each side's damage per turn, who moves first, how many actions each side gets).
- **`MoveStrategy`**: the pick for the difficulty (weighted random among the near-best moves on fair) and corrections (replace moves that can't work, replace support moves that would do nothing, take a guaranteed KO).
- **`LoadoutStrategy`**: role-based loadouts.
- **`OpponentStrategy`** + **`PokemonStrength`**: fair pools and picks by simulated strength.

## One system for every battle

Battle quality isn't tuned battle by battle. PokeBattleKit's tests run against an offline snapshot of all of PokeAPI (every move and every Pokémon):

- **Move catalogue audit**: every PokeAPI value the engine reads must be one it knows, and every learnable move with an unusual mechanic must be explicitly modeled, approximated or excluded. A new or misread move fails a named test.
- **Whole-Pokédex simulation**: AI-vs-AI battles with matchups picked the way "Smart pick" picks them, checking battle length, stalls, unusable picks, missed KOs, loadouts without an attack, each difficulty's win rate, and that the strength ratings still predict outcomes. A calibration run finds the difficulty level gaps.

## Tuning the AI

The weights live in `MoveScoring.Weights` inside PokeBattleKit. They're public static properties, so you can read (and fork) them to experiment with AI behavior:

| Weight | What it controls | Default |
| --- | --- | --- |
| `koBonus` | Bonus for a KO, scaled by its chance | 40 |
| `twoHitKOBonus` | Bonus for setting up a KO next turn | 10 |
| `futureDiscount` | Discount on value that pays off in later turns | 0.75 |
| `horizon` | Future actions boosts, statuses and heals are valued over | 2 |
| `repeatPenalty` | Mild penalty for repeating a move, to vary near-equal picks | 3 |
| `supportStreakDecay` | How fast repeated non-attacking moves lose value (prevents stall loops) | 0.5 |

After a change, run PokeBattleKit's tests to see the effect across the whole Pokédex, then regenerate the ratings and recalibrate the difficulty.

---

# Local Multiplayer 🏟

Both players open the Gym tab, which advertises and browses simultaneously. Nearby trainers appear in a discovery list; tapping one sends an invite. Once both accept, each picks a Pokemon and four moves, then the battle begins. All communication is peer-to-peer over Wi-Fi or Bluetooth via MultipeerConnectivity. No servers, no accounts, no internet required.

## Authority model

**Host-authoritative.** The device that accepts the invitation becomes the host; the one that sent it becomes the guest. Only the host runs `BattleEngine`. The guest sends its move choice, receives resolved events, and renders them. This eliminates desync from random rolls (crits, accuracy, status chance).

## Message protocol

A single `Codable` enum (`BattleMessage`) covers the full lifecycle. It's a versioned wire format (`MultipeerProtocol.version`); peers reject mismatches.

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
   │ (tap Battle: challenge this Pokémon)
   ▼
Fighter picker sheet  <-- your team first, Smart pick (AI)
   │ (tap your fighter)
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

The first launch downloads everything once; every later launch reads from SwiftData with zero network calls.

| Worker | What it pulls | When |
| --- | --- | --- |
| `PokeBattleKit` | Type chart (18 type damage relations) + full move catalogue | App launch via `PokeBattleKit.initialize()` |
| `PokedexRepository` | `/pokemon?limit=1150` index, then every detail + species in parallel | First launch, with a progress overlay |
| `EvolutionService` | Every evolution chain referenced by the species | First launch (prefetch), then cache-first on detail screens |
| `PokedexRepository` | Full item catalogue, grouped by category | First visit to the Items tab |

Decoding happens in parallel off the main thread, the import runs on the background `PokedexStore`, and the main thread only receives whole-percent progress updates. Sprites are fetched, decoded, and color-analyzed concurrently as grid cells appear; dominant colors are cached in-process by pokemon id.

---

# Design System 🎨

Pixel font, gameboy-style aesthetic, glass effects:

- **`DesignKit.Spacing.Primitive`**: the spacing scale (`s0`, `s2`, `s4`, `s6`, `s8`, `s12`, `s16`, then 8-point steps up to `s56`). Every padding and stack spacing in the app uses it instead of literal numbers.
- **`Chip`**: small inline pill used for type tags, generation badges, status pills, effectiveness markers. Always a 2-point corner radius (capsules look too modern next to the pixel font).
- **`MoveCell`**: shared between the battle move grid and the loadout move picker, switched via a `Mode` enum.
- **`TypeColor`**: centralized type-to-color map used by every move chip, type tag, and weakness grid row.
- **`PokemonGrid<Cell>`**: generic grid taking a `GridLayout` and a `@ViewBuilder` cell closure. Handles only scrolling and layout; navigation, search, and overlays are the caller's responsibility.
- **`PokedexGridView`**: wraps `PokemonGrid` with color-analyzed cells (dominant-color backgrounds via `ImageColorAnalyzer`), a loading overlay, and either `NavigationLink` routing (compact width) or selection (side-by-side layout). Toggleable between 3 and 4 columns.
- **`PokemonSpriteCard`**: sprite-over-name grid cell with type chips. Used by search results, bookmarks, type lists, opponent picker, and multiplayer fighter picker.
- **`PokemonPickerGrid`**: wraps `PokemonGrid` with a toolbar search bar and cached haystack filtering (name, type, genus, habitat, legendary/mythical, abilities). Used by opponent picker, multiplayer fighter picker, and bookmarks.
- **`GridLayout`**: single source of truth for grid column counts and spacing across the app (`.two`, `.three`, `.four`).
- **`MoveLoadoutView`**: pokemon summary card + `MovePickerGrid` + caller-provided bottom bar slot. Shared across single-player and multiplayer move selection.
- **`MovePickerGrid`**: 2-column move grid with toggle selection and optional type effectiveness annotations.
- **`pixelPercent()` / `pixelFontSafe`**: formatting helpers that avoid the non-breaking spaces format styles insert, which the pixel font would draw as underscores.

---

# Modernized with Apple's Xcode agent skills 🧠

The codebase has been reviewed and modernized with the **agent skills Apple ships for Xcode's coding assistant**. These are Apple-written guides that an agent loads before reviewing or writing code. Export them to disk with:

```sh
xcrun agent skills export --output-dir xcode-skills
```

Each skill is a folder with a `SKILL.md` and a `references/` directory. The ones applied here:

| Skill | Applied to |
| --- | --- |
| `swiftui-specialist` | Data flow and `@Observable` granularity, environment values (`@Entry`), view structure, `ForEach` identity, conditional modifiers, soft-deprecated APIs, animations (`@Animatable`) |
| `swiftui-whats-new-27` | SDK 27 changes (`@State` macro, `@ContentBuilder`, toolbar, `AsyncImage`, swipe and reorder APIs) |
| `app-resizability` | Size-class driven layout instead of device or idiom checks, ready for resizable windows and the foldable iPhone Duo |

On top of that, the project moved to the Swift 6 language mode with the concurrency setup described in [Concurrency model](#concurrency-model).

---

# Dependencies 🔗

| Package | What it does |
| --- | --- |
| [Networking](https://github.com/brillcp/Networking) | Thin actor-based `URLSession` wrapper with a generic `Requestable` protocol driving every PokeAPI endpoint |
| [PokeBattleKit](https://github.com/brillcp/PokeBattleKit) | Standalone battle engine: damage calculator, type chart, move/combatant models, and heuristic AI strategies (scoring, picking, adjustments) |

```swift
dependencies: [
    .package(url: "https://github.com/brillcp/Networking.git", .upToNextMajor(from: "0.10.1")),
    .package(url: "https://github.com/brillcp/PokeBattleKit.git", .upToNextMajor(from: "0.2.0"))
]
```

---

# Requirements ❗️

- Xcode 26+
- iOS 26+ (for Liquid Glass, `@Observable`, SwiftData)
- Swift 6 language mode (default actor isolation `nonisolated`, Approachable Concurrency)
- Local Network permission for multiplayer (prompted automatically on first Gym use)
