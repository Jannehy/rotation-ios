import AVFoundation
import SwiftUI

@main
struct RotationApp: App {
    @StateObject private var session = Session.shared
    // Read here so the whole tree redraws when the colour changes; Palette
    // itself reads the same stored value.
    @AppStorage(Accent.key) private var accentName = Accent.sunset.rawValue
    @AppStorage("season.remind") private var seasonRemind = true

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(Accent(rawValue: accentName)?.accent ?? Palette.accent)
                .id(accentName)
                .task {
                    // The story is the only thing here that makes a sound;
                    // it should mix with music rather than take it over, and
                    // it should be audible with the ringer switch off.
                    try? AVAudioSession.sharedInstance()
                        .setCategory(.playback, options: [.mixWithOthers])
                    await SeasonReminder.refreshIfAllowed(wanted: seasonRemind)
                }
        }
    }
}
