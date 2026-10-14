import Foundation
import FoundationModels

/// Owns the on-device Foundation Models session and per-decision instruction
/// text. Each call to `decide(...)` makes one structured-generation request
/// and falls back to the heuristic on error or model unavailability.
///
/// Uses FoundationModels guided generation (`@Generable` output types) only;
/// no tools are registered, since every fact the model needs is in the
/// prompt. An actor so availability checks and inference stay off the main
/// actor.
actor LanguageModelClient {
    private let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)

    var isAvailable: Bool {
        if case .available = model.availability { return true }
        return false
    }
}

// MARK: - Structured Generation

extension LanguageModelClient {

    /// Generate a structured result using @Generable.
    func generate<T: Generable>(
        prompt: String,
        generating type: T.Type,
        temperature: Double,
        instructions: Instructions
    ) async throws -> T {
        // A fresh session per decision: turns are independent, and not
        // carrying a transcript keeps the context small and avoids earlier
        // answers biasing later ones.
        let session = LanguageModelSession(model: model, instructions: instructions.text)
        return try await session.respond(
            to: prompt,
            generating: type,
            options: .init(temperature: temperature)
        ).content
    }

    /// Structured decision: tries @Generable generation,
    /// falls back to heuristic if the model is unavailable or fails.
    ///
    /// `resolve` maps the raw model output onto a real option (or `nil` if
    /// it named something invalid). `adjust` runs on whichever pick wins,
    /// model or fallback, so deterministic guardrails apply to both. The
    /// prompt is an autoclosure so it isn't built when the model is
    /// unavailable.
    func decide<Pick, Result: Generable>(
        fallback: Pick,
        prompt: @autoclosure () -> String,
        generating type: Result.Type,
        temperature: Double,
        instructions: Instructions,
        resolve: (Result) -> Pick?,
        adjust: (Pick) -> Pick
    ) async -> Pick {
        guard isAvailable else {
            aiLog("LLM unavailable, using heuristic fallback")
            return adjust(fallback)
        }
        do {
            let promptText = prompt()
            aiLog("PROMPT:\n\(promptText)")
            let result = try await generate(
                prompt: promptText, generating: type,
                temperature: temperature, instructions: instructions
            )
            aiLog("LLM RESULT: \(result)")
            if let pick = resolve(result) {
                let adjusted = adjust(pick)
                aiLog("LLM pick accepted")
                return adjusted
            }
            aiLog("LLM resolve failed, using fallback")
        } catch {
            aiLog("LLM error: \(error), using fallback")
        }
        return adjust(fallback)
    }
}

// MARK: - Instructions

extension LanguageModelClient {
    /// Wraps an instruction blob loaded from the app bundle, with a
    /// hard-coded fallback when the resource file is missing.
    struct Instructions: Sendable {
        let text: String

        static let move = Instructions(
            resource: "BattleAIMoveInstructions",
            fallback: "You are a Pokemon battle assistant. Pick the move that maximises damage output this turn. Return only the move name."
        )
        static let opponent = Instructions(
            resource: "BattleAIOpponentInstructions",
            fallback: "You are a Pokemon battle matchmaker. Pick a fair and interesting opponent."
        )
        static let loadout = Instructions(
            resource: "BattleAILoadoutInstructions",
            fallback: "You are a Pokemon battle assistant picking a loadout. Pick 4 moves with good type coverage and power."
        )

        private init(resource: String, fallback: String) {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "md"),
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else {
                self.text = fallback
                return
            }
            self.text = text
        }
    }
}
