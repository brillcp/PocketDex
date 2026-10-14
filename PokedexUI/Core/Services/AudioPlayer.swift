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
/// never block the main thread.
actor AudioPlayer {
    private var player: AVPlayer?

    init() {
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
