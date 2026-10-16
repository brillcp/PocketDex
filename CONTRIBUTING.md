# Contributing

Thanks for taking a look. Issues and pull requests are welcome.

## Before you start

- Open an issue first for anything bigger than a small fix, so we can agree on the approach.
- Battle rules and AI live in [PokeBattleKit](https://github.com/brillcp/PokeBattleKit). Engine or balance changes belong there, with its simulation tests, not in this app.

## Building

Open `PokedexUI.xcodeproj` in Xcode (see the README for the required version), pick your own signing team for the `PokedexUI` target, and run. The first launch downloads the Pokédex from [PokeAPI](https://pokeapi.co), so it needs a connection.

## Code style

- Swift 6 language mode with strict concurrency: new code should build without warnings.
- Follow the existing structure (`App` / `Core` / `Features` / `DesignSystem`) and keep views behind their view model protocols.
- User-facing text goes in `Localizable.strings` with a dotted key (`screen.element`). Views pass the key as a literal (`Text("myTeam.title")`), interpolating values for formatted strings (`Text("move.pp \(pp)")` is the key `"move.pp %lld"`); new components take `LocalizedStringKey` for their text. Use `Localized("key", args)` only where a `String` is needed. Plurals go in `Localizable.stringsdict`.
- Comment the *why* (threading decisions, non-obvious workarounds), not the *what*.

## Pull requests

- Keep each PR to one change, with a short description of what and why.
- Mention how you tested it (device or simulator, iOS version).
