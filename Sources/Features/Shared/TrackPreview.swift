import AVFoundation
import Foundation

/// Thirty seconds of a song, from a third of the way in – which is where a
/// song usually says what it is.
///
/// Deliberately not a full player: Rotation counts music, it does not play
/// it. This is a taste, so a name in a list can be recognised again.
@MainActor
final class TrackPreview: ObservableObject {
    @Published private(set) var playing: String?

    private var player: AVPlayer?
    private var stopper: Task<Void, Never>?

    private static let seconds: Double = 30
    private static let volume: Float = 0.9

    func isPlaying(_ trackID: String) -> Bool { playing == trackID }

    func toggle(_ trackID: String, source: DataSource?) {
        if playing == trackID { stop(); return }
        stop()
        guard let source, let url = source.streamURL(trackID) else { return }

        let item = AVPlayerItem(url: url)
        let next = AVPlayer(playerItem: item)
        next.volume = 0
        player = next
        playing = trackID

        stopper = Task {
            if let duration = try? await item.asset.load(.duration).seconds,
               duration.isFinite, duration > 45 {
                await next.seek(to: CMTime(seconds: duration * 0.3,
                                           preferredTimescale: 600))
            }
            guard !Task.isCancelled else { return }
            next.play()
            await ramp(next, to: Self.volume, over: 0.5)
            try? await Task.sleep(nanoseconds: UInt64(Self.seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await ramp(next, to: 0, over: 0.7)
            stop()
        }
    }

    func stop() {
        stopper?.cancel()
        stopper = nil
        player?.pause()
        player = nil
        playing = nil
    }

    private func ramp(_ player: AVPlayer, to target: Float, over span: Double) async {
        let from = player.volume
        let steps = max(1, Int(span * 30))
        for step in 1...steps {
            if Task.isCancelled { return }
            player.volume = from + (target - from) * Float(step) / Float(steps)
            try? await Task.sleep(nanoseconds: UInt64(span / Double(steps) * 1_000_000_000))
        }
    }
}
