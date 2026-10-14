import SwiftUI
import PokeBattleKit

/// One-shot helper that pulls sprite images for both combatants, extracts
/// dominant colors, and writes them onto the animator's per-side cues so
/// log names tint to match each Pokemon. Both sprites download in parallel;
/// the color analyzer caches by Pokémon id.
@MainActor
struct SpriteColorResolver {
    let spriteLoader: SpriteLoading
    let imageColorAnalyzer: ImageColorAnalyzing

    func resolve(
        playerID: Int,
        playerSpriteURL: String,
        opponentID: Int,
        opponentSpriteURL: String,
        animator: BattleAnimator
    ) async {
        async let playerImage   = spriteLoader.spriteImage(from: playerSpriteURL)
        async let opponentImage = spriteLoader.spriteImage(from: opponentSpriteURL)
        let (pImg, oImg) = await (playerImage, opponentImage)
        if let pImg, let color = await imageColorAnalyzer.dominantColor(for: playerID, image: pImg) {
            animator.mutateCues(.player) { $0.color = color }
        }
        if let oImg, let color = await imageColorAnalyzer.dominantColor(for: opponentID, image: oImg) {
            animator.mutateCues(.opponent) { $0.color = color }
        }
    }
}
