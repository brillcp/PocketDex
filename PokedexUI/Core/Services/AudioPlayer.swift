import AVFoundation

/// Audio playback for pokemon cries. Shared via `AppContainer.audioPlayer`.
protocol AudioPlaying: Sendable {
    /// Whether audio is currently playing.
    var isPlaying: Bool { get async }
    /// Play audio from a URL string, stopping any current playback.
    func play(from url: String) async
    /// Stop playback and reset to the beginning.
    func stop() async
}

/// Owns the `AVPlayer` on its own executor so stream setup and buffering
/// never block the main thread. An actor (rather than a stateless struct
/// like `SpriteLoader`) because `player` is mutable state that `play` and
/// `stop` must not race on. No `@concurrent` is needed: actor methods
/// already run off the caller's actor.
actor AudioPlayer {
    private var player: AVPlayer?

    init() {
        // `.playback` so cries are audible with the silent switch on;
        // `.mixWithOthers` so they don't stop the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
    }
}

// MARK: - AudioPlaying

extension AudioPlayer: AudioPlaying {
    var isPlaying: Bool {
        guard let player else { return false }
        return player.timeControlStatus == .playing
    }

    func play(from url: String) {
        guard let url = URL(string: url) else { return }

        if isPlaying {
            stop()
        }

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
    }
}
