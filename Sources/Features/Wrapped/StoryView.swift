import AVFoundation
import SwiftUI

/// The year as a story: full screen, one card at a time, running by itself.
///
/// Hold to pause, tap left or right to step. Two cards ask before they tell,
/// because a number lands differently when you have just guessed at it. The
/// music is the user's own: four of the cards bring a song with them, the
/// others let whatever is playing run on.
struct StoryView: View {
    let data: Wrapped
    @EnvironmentObject private var session: Session
    @Environment(\.dismiss) private var dismiss

    @State private var cards: [StoryCard] = []
    @State private var index = 0
    @State private var progress: Double = 0
    @State private var paused = false
    @State private var answers: [Int: Bool] = [:]
    @State private var shakes: CGFloat = 0
    @State private var confettiAt: Date?
    @State private var lastStep = Date.distantPast
    @State private var holding: Task<Void, Never>?
    @AppStorage("story.muted") private var muted = false

    @StateObject private var player = StoryPlayer()

    private static let hold: Double = 7
    private static let question: Double = 14
    private static let answered: Double = 1.6
    private static let cooldown: Double = 0.5

    var body: some View {
        ZStack {
            // The whole page steps and pauses – but only from behind the
            // card, so a button on a question keeps its own tap.
            backdrop
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .global) { location in
                    let back = location.x < UIScreen.main.bounds.width * 0.33
                    // A question and the last card wait for a decision, so
                    // tapping onwards is off there. Back always works.
                    if back { step(-1) } else if !(cards[safe: index]?.wantsTouches ?? false) {
                        step(1)
                    }
                }
                // A press only counts as a hold once it outlasts a tap,
                // otherwise every step would dim the card for a moment.
                .onLongPressGesture(minimumDuration: 60, maximumDistance: 60,
                                    pressing: { pressing in
                    holding?.cancel()
                    if pressing {
                        holding = Task {
                            try? await Task.sleep(nanoseconds: 220_000_000)
                            if !Task.isCancelled { paused = true }
                        }
                    } else {
                        paused = false
                    }
                }, perform: { })

            VStack(spacing: 0) {
                bars
                controls
                Spacer(minLength: 0)
                if let card = cards[safe: index] {
                    card.view(StoryContext(data: data,
                                           answered: answers[index],
                                           answer: answer,
                                           skip: { advance(1) },
                                           close: { dismiss() },
                                           scoreLine: score))
                        .id(index)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.horizontal, 22)
                        .opacity(paused ? 0.55 : 1)
                        .modifier(Shake(travel: shakes))
                        .allowsHitTesting(card.wantsTouches)
                }
                Spacer(minLength: 0)
            }

            if let confettiAt {
                ConfettiView(seed: confettiAt)
                    .allowsHitTesting(false)
                    .id(confettiAt)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: start)
        .onDisappear { player.stop() }
        .onChange(of: muted) { value in player.setMuted(value) }
        .task(id: index) { await run() }
    }

    // MARK: - Chrome

    private var bars: some View {
        HStack(spacing: 4) {
            ForEach(cards.indices, id: \.self) { position in
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.22))
                        Capsule().fill(.white)
                            .frame(width: geometry.size.width * fill(position))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private var controls: some View {
        HStack(spacing: 6) {
            Spacer()
            Button { muted.toggle() } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            Button { dismiss() } label: { Image(systemName: "xmark") }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .buttonStyle(StoryIconStyle())
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    /// How the guessing went, once anything was guessed.
    private var score: String? {
        let given = answers.values
        guard !given.isEmpty else { return nil }
        return String(format: String(localized: "%1$d of %2$d questions right"),
                      given.filter { $0 }.count, given.count)
    }

    private func fill(_ position: Int) -> Double {
        if position < index { return 1 }
        if position > index { return 0 }
        return progress
    }

    private var backdrop: some View {
        ZStack {
            Color(red: 0.027, green: 0.027, blue: 0.047)
            RadialGradient(colors: [Palette.accent.opacity(0.35), .clear],
                           center: .top, startRadius: 0, endRadius: 620)
            RadialGradient(colors: [Palette.accentAlt.opacity(0.30), .clear],
                           center: .bottomLeading, startRadius: 0, endRadius: 560)
        }
    }

    // MARK: - Running

    private func start() {
        cards = StoryCard.all(for: data)
        index = 0
        player.setMuted(muted)
    }

    /// Counts the card down, then moves on. Pausing simply stops counting.
    private func run() async {
        guard let card = cards[safe: index] else { return }
        progress = 0
        play(card.music)
        // The last card holds the picture and the share button, so it waits
        // for the reader instead of closing on its own.
        if card.isFinale { progress = 1; return }
        var span = card.isQuestion ? Self.question : Self.hold
        var elapsed: Double = 0
        let tick: Double = 1.0 / 30
        while elapsed < span {
            try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
            if Task.isCancelled { return }
            if paused { continue }
            // An answer shortens what is left: enough to see the confetti.
            if card.isQuestion, answers[index] != nil, span > Self.answered {
                span = min(span, elapsed + Self.answered)
            }
            elapsed += tick
            progress = min(1, elapsed / span)
        }
        advance(1)
    }

    private func advance(_ direction: Int) {
        let next = index + direction
        if next >= cards.count { dismiss(); return }
        withAnimation(.easeOut(duration: 0.35)) { index = max(0, next) }
    }

    /// Two taps that close together are one thumb, not a wish to skip two.
    private func step(_ direction: Int) {
        guard Date().timeIntervalSince(lastStep) > Self.cooldown else { return }
        lastStep = Date()
        advance(direction)
    }

    private func answer(_ correct: Bool) {
        guard answers[index] == nil else { return }
        answers[index] = correct
        if correct {
            let moment = Date()
            confettiAt = moment
            // Taken down again, or the last bits sit at the edge of the
            // screen for the rest of the story.
            Task {
                try? await Task.sleep(nanoseconds: 3_600_000_000)
                if confettiAt == moment { confettiAt = nil }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.easeInOut(duration: 0.5)) { shakes += 1 }
        }
    }

    private func play(_ track: TrackEntry?) {
        guard let source = session.source,
              let url = source.streamURL(track?.id) else { return }
        player.play(url, muted: muted)
    }

}

/// The flinch of a wrong answer.
private struct Shake: GeometryEffect {
    var travel: CGFloat

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 9 * sin(travel * .pi * 4), y: 0))
    }
}

private struct StoryIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 38, height: 38)
            .background(.white.opacity(configuration.isPressed ? 0.25 : 0.12), in: Circle())
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
