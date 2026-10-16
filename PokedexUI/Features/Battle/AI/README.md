# Battle AI

The AI opponent, built entirely on [PokeBattleKit](https://github.com/brillcp/PokeBattleKit)'s
rule-based AI. There's no language model.

| Decision | Method | How |
|---|---|---|
| Fighter | `chooseFighter` | `MatchmakingStrategy.pick` from the opponent's side: a random fair matchup by simulated strength (`PokemonStrength`), favouring tense ones, skipping recent suggestions |
| Loadout | `chooseLoadout` | `LoadoutStrategy.heuristicPick` + the difficulty's handicap |
| Move each turn | `chooseMove` | `MoveStrategy.heuristicPick` for the difficulty + `MoveStrategy.adjust` |

## Files

```
AI/
  BattleAIService.swift           protocol + actor, the three decisions
  BattleAIDriver.swift            per-battle history and scouted player moves
  Candidate+Pokemon.swift         Sendable Pokémon DTO for opponent picks
```

Everything that decides how well the AI plays lives in PokeBattleKit, where
its tests check it across the whole Pokédex. Change the AI there, not here.
