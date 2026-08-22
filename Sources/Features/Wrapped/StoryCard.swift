import AVFoundation
import SwiftUI

/// What a card needs to know about the year it is part of.
struct StoryContext {
    let data: Wrapped
    /// nil while unanswered, then whether the guess was right.
    let answered: Bool?
    let answer: (Bool) -> Void
    /// Moves on without counting the question at all.
    let skip: () -> Void
    /// Closes the story – the last card offers it as a button.
    let close: () -> Void
    /// "2 of 2 questions right", or nil when nothing was asked.
    var scoreLine: String?
}

/// One screen of the story. `music` is set on the four cards that bring a
/// song with them; the rest let whatever is playing run on.
struct StoryCard {
    let music: TrackEntry?
    let isQuestion: Bool
    /// The last card stays put: it holds the picture and the share button.
    let isFinale: Bool
    let content: (StoryContext) -> AnyView

    init(music: TrackEntry? = nil,
         isQuestion: Bool = false,
         isFinale: Bool = false,
         @ViewBuilder content: @escaping (StoryContext) -> some View) {
        self.music = music
        self.isQuestion = isQuestion
        self.isFinale = isFinale
        self.content = { AnyView(content($0)) }
    }

    /// Cards that hold something to press keep their touches; everything
    /// else lets them through to the page behind, which does the stepping.
    var wantsTouches: Bool { isQuestion || isFinale }

    func view(_ context: StoryContext) -> AnyView { content(context) }

    // MARK: - The year, in order

    static func all(for data: Wrapped) -> [StoryCard] {
        var cards: [StoryCard] = []
        let artists = data.artists
        let tracks = data.tracks

        cards.append(StoryCard(music: opening(for: data)) { _ in
            VStack(spacing: 12) {
                Text(String(data.year))
                    .font(.system(size: 96, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [Palette.accent, Palette.accentAlt],
                                       startPoint: .leading, endPoint: .trailing))
                StoryTitle(String(localized: "Your year in music"))
                StorySub(String(localized: "Twelve months, a few numbers and two questions."))
            }
        })

        cards.append(StoryCard { _ in
            VStack(spacing: 10) {
                StoryKicker(String(localized: "That is how long you listened"))
                CountUp(target: data.summary.seconds / 60)
                StorySub(String(format: String(localized: "%d plays on %d days"),
                                data.summary.plays, data.summary.activeDays))
            }
        })

        if artists.count >= 4, let first = artists.first {
            let options = decoys(artists.dropFirst().map(\.name), count: 3)
            cards.append(StoryCard(isQuestion: true) { context in
                QuizCard(question: String(localized: "Who was your artist of the year?"),
                         right: first.name, others: options,
                         numeric: false, context: context)
            })
            cards.append(StoryCard(music: data.artistTrack) { _ in
                VStack(spacing: 12) {
                    Artwork(art: first.art, name: first.name, size: 220, rounded: true)
                    StoryKicker(String(localized: "Your artist of the year"))
                    StoryTitle(first.name)
                    StorySub("\(Format.number(first.plays)) "
                             + String(localized: "plays") + " · "
                             + String(format: String(localized: "%d%% of everything you played"),
                                      data.devotion))
                }
            })
        }

        if !artists.isEmpty {
            cards.append(StoryCard { _ in
                StoryList(title: String(localized: "Your top artists"),
                          rows: artists.prefix(5).map {
                              StoryList.Row(name: $0.name,
                                            meta: "\(Format.number($0.plays)) "
                                                + String(localized: "plays"),
                                            art: $0.art, rounded: true)
                          })
            })
        }

        if tracks.count >= 2, let best = tracks.first {
            cards.append(StoryCard(isQuestion: true) { context in
                QuizCard(question: String(localized: "How often did your favourite song play?"),
                         right: String(best.plays),
                         others: guesses(around: best.plays),
                         numeric: true, context: context)
            })
            cards.append(StoryCard(music: best) { _ in
                VStack(spacing: 12) {
                    Artwork(art: best.art, name: best.title, size: 220)
                    StoryKicker(String(localized: "Your track of the year"))
                    StoryTitle(best.title)
                    StorySub("\(best.artist) · \(Format.number(best.plays)) "
                             + String(localized: "plays"))
                }
            })
        }

        if !tracks.isEmpty {
            cards.append(StoryCard { _ in
                StoryList(title: String(localized: "Your top tracks"),
                          rows: tracks.prefix(5).map {
                              StoryList.Row(name: $0.title, meta: $0.artist,
                                            art: $0.art, rounded: false)
                          })
            })
        }

        let genre = data.genres.first
        if genre != nil || data.clock.peakHour != nil {
            cards.append(StoryCard(music: data.genreTrack) { _ in
                VStack(spacing: 10) {
                    if let genre {
                        StoryKicker(String(localized: "Your genre"))
                        StoryTitle(genre.name)
                    }
                    if let hour = data.clock.peakHour {
                        StoryKicker(String(localized: "Your hour")).padding(.top, 14)
                        Text(Format.hour(hour))
                            .font(.system(size: 62, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
            })
        }

        if data.streak > 0 {
            cards.append(StoryCard { _ in
                VStack(spacing: 10) {
                    StoryKicker(String(localized: "Your longest streak"))
                    CountUp(target: data.streak, grouping: false)
                    StorySub(String(format: String(localized: "%d days in a row"), data.streak))
                }
            })
        }

        if !data.discoveries.isEmpty {
            cards.append(StoryCard { _ in
                VStack(spacing: 14) {
                    StoryKicker(String(localized: "New to you"))
                    FlowLayout(spacing: 8) {
                        ForEach(data.discoveries.prefix(8)) { item in
                            Text(item.name)
                                .font(.subheadline)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(.white.opacity(0.12), in: Capsule())
                        }
                    }
                    .foregroundStyle(.white)
                }
            })
        }

        if let previous = data.previous, previous.plays > 0 {
            let delta = Int((Double(data.summary.plays - previous.plays)
                             / Double(previous.plays) * 100).rounded())
            cards.append(StoryCard { _ in
                VStack(spacing: 10) {
                    StoryKicker(String(format: String(localized: "Against %d"), previous.year))
                    Text("\(delta >= 0 ? "+" : "")\(Format.number(delta)) %")
                        .font(.system(size: 62, weight: .black))
                        .foregroundStyle(.white)
                    StorySub("\(Format.number(previous.plays)) → "
                             + "\(Format.number(data.summary.plays)) "
                             + String(localized: "plays"))
                }
            })
        }

        cards.append(StoryCard(isFinale: true) { context in
            StoryFinale(data: data, answers: context)
        })
        return cards
    }

    // MARK: - Choosing

    /// The opening song: not the winner, and not its artist's either.
    private static func opening(for data: Wrapped) -> TrackEntry? {
        let banned = Set([data.tracks.first?.id, data.artistTrack?.id].compactMap { $0 })
        let rest = data.tracks.filter { !banned.contains($0.id) }
        return rest.randomElement() ?? data.tracks.first
    }

    /// Three other names, spread over the list so the answer is not obvious.
    private static func decoys(_ names: [String], count: Int) -> [String] {
        let unique = Array(NSOrderedSet(array: names).compactMap { $0 as? String })
        guard unique.count > count else { return unique }
        let step = max(1, unique.count / count)
        var picked: [String] = []
        var position = 0
        while picked.count < count, position < unique.count {
            picked.append(unique[position])
            position += step
        }
        return picked
    }

    /// Plausible wrong counts around the real one.
    private static func guesses(around real: Int) -> [String] {
        var spread: [String] = []
        for factor in [0.45, 0.7, 1.6, 2.3] {
            let value = max(1, Int((Double(real) * factor).rounded()))
            let text = String(value)
            if value != real, !spread.contains(text) { spread.append(text) }
        }
        return Array(spread.prefix(3))
    }
}

// MARK: - The pieces a card is made of

struct StoryTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .black))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
    }
}

struct StoryKicker: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(.white.opacity(0.7))
    }
}

struct StorySub: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.78))
    }
}

/// A number that arrives rather than appears.
struct CountUp: View {
    let target: Int
    var grouping = true
    @State private var shown = 0

    var body: some View {
        Text(grouping ? Format.number(shown) : String(shown))
            .font(.system(size: 70, weight: .black))
            .monospacedDigit()
            .foregroundStyle(.white)
            .task {
                let steps = 34
                for step in 0...steps {
                    let share = Double(step) / Double(steps)
                    // Fast at first, gentle at the end.
                    let eased = 1 - pow(1 - share, 3)
                    shown = Int((Double(target) * eased).rounded())
                    try? await Task.sleep(nanoseconds: 35_000_000)
                }
                shown = target
            }
    }
}

struct StoryList: View {
    struct Row: Identifiable {
        let name: String
        let meta: String
        let art: String?
        let rounded: Bool
        var id: String { name + meta }
    }

    let title: String
    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StoryKicker(title)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 18, alignment: .trailing)
                    Artwork(art: row.art, name: row.name, size: 48, rounded: row.rounded)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.name).font(.body).lineLimit(1)
                        Text(row.meta).font(.caption)
                            .foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A question, and what happens when it is answered.
struct QuizCard: View {
    let question: String
    let right: String
    let others: [String]
    let numeric: Bool
    let context: StoryContext

    @State private var options: [String] = []
    @State private var picked: String?

    var body: some View {
        VStack(spacing: 14) {
            Text(question)
                .font(.system(size: 26, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            let columns = numeric ? [GridItem(.flexible()), GridItem(.flexible())]
                                  : [GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button { pick(option) } label: {
                        Text(option)
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            // The whole tile answers, not only the word on it.
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(background(for: option),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.18)))
                    .foregroundStyle(ink(for: option))
                    .disabled(picked != nil)
                }
            }

            if let picked {
                Text(picked == right ? String(localized: "Right!")
                                     : String(localized: "Not quite."))
                    .font(.headline)
                    .foregroundStyle(.white)
            } else {
                Button(String(localized: "Skip")) { context.skip() }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .onAppear { if options.isEmpty { options = ([right] + others).shuffled() } }
    }

    private func pick(_ option: String) {
        guard picked == nil else { return }
        picked = option
        context.answer(option == right)
    }

    private func background(for option: String) -> Color {
        guard picked != nil else { return .white.opacity(0.1) }
        if option == right { return Color(red: 0.165, green: 0.831, blue: 0.643) }
        if option == picked { return Palette.accent.opacity(0.35) }
        return .white.opacity(0.1)
    }

    private func ink(for option: String) -> Color {
        picked != nil && option == right ? Color(red: 0.02, green: 0.14, blue: 0.11) : .white
    }
}

/// The last card: the score, the picture, and a way to share it.
struct StoryFinale: View {
    let data: Wrapped
    let answers: StoryContext
    @EnvironmentObject private var session: Session
    @AppStorage("rotation.cardtheme") private var themeName = CardTheme.sunset.rawValue
    @State private var image: UIImage?
    @State private var sharing = false

    var body: some View {
        VStack(spacing: 14) {
            StoryKicker(String(format: String(localized: "That was your %d"), data.year))
            if let score = answers.scoreLine {
                // A headline size here fights the picture below it and breaks
                // mid-sentence on a narrow screen; this is a caption.
                Text(score)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button {
                    sharing = true
                } label: {
                    Label(String(localized: "Share image"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                Button(String(localized: "Close")) { answers.close() }
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .sheet(isPresented: $sharing) {
            if let image { ActivityView(items: [image]) }
        }
        .task {
            // The artwork has to be in hand before drawing: the card is
            // painted in one pass and cannot wait for a download.
            var cover: UIImage?
            if let art = data.artists.first?.art,
               let url = session.source?.artworkURL(art, size: 600),
               let (bytes, _) = try? await URLSession.shared.data(from: url) {
                cover = UIImage(data: bytes)
            }
            let theme = CardTheme(rawValue: themeName) ?? .sunset
            image = RotationCard.render(
                data: data,
                name: data.user?.name ?? session.me?.user.name ?? "",
                cover: cover, theme: theme)
        }
    }
}

/// The confetti of a right answer.
///
/// Every bit's path is derived from its number, not drawn anew: a random
/// value inside the view would be rolled again on each redraw, and the
/// confetti would twitch whenever anything else on screen changed.
struct ConfettiView: View {
    let seed: Date
    private static let count = 70
    private let colours: [Color] = [
        Palette.accent, Palette.accentAlt,
        Color(red: 0.165, green: 0.831, blue: 0.643),
        Color(red: 1.0, green: 0.82, blue: 0.4), .white,
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<Self.count, id: \.self) { index in
                    ConfettiBit(colour: colours[index % colours.count],
                                area: geometry.size,
                                spread: wobble(index, 0.13),
                                spin: 180 + wobble(index, 0.37) * 440,
                                span: 1.5 + wobble(index, 0.71) * 1.2,
                                delay: Double(index % 12) * 0.03)
                }
            }
            .clipped()
        }
    }

    /// A settled value in 0…1 for one bit, stable across redraws.
    private func wobble(_ index: Int, _ salt: Double) -> Double {
        let value = sin(Double(index) * 12.9898 + salt * 78.233) * 43758.5453
        return value - value.rounded(.down)
    }
}

private struct ConfettiBit: View {
    let colour: Color
    let area: CGSize
    let spread: Double
    let spin: Double
    let span: Double
    let delay: Double
    @State private var fallen = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(colour)
            .frame(width: 9, height: 14)
            .position(x: area.width * spread, y: fallen ? area.height + 30 : -20)
            .rotationEffect(.degrees(fallen ? spin : 0))
            .onAppear {
                withAnimation(.linear(duration: span).delay(delay)) { fallen = true }
            }
    }
}

/// Plays the songs behind the story, fading between them.
@MainActor
final class StoryPlayer: ObservableObject {
    private var player: AVPlayer?
    private var current: URL?
    private var fade: Task<Void, Never>?

    private static let volume: Float = 0.55

    func play(_ url: URL, muted: Bool) {
        guard current != url else { return }
        current = url
        fade?.cancel()
        fade = Task {
            // The song that is running bows out first; cutting it dead is
            // what makes a change feel like a jump.
            await ramp(to: 0, over: 0.45)
            guard !Task.isCancelled else { return }
            let item = AVPlayerItem(url: url)
            let next = AVPlayer(playerItem: item)
            next.volume = 0
            next.isMuted = muted
            player?.pause()
            player = next
            // A song opens where it is worth hearing, not on its intro.
            if let seconds = try? await item.asset.load(.duration).seconds,
               seconds.isFinite, seconds > 45 {
                let share = Double.random(in: 0.32...0.5)
                await next.seek(to: CMTime(seconds: seconds * share, preferredTimescale: 600))
            }
            guard !Task.isCancelled else { return }
            next.play()
            await ramp(to: muted ? 0 : Self.volume, over: 1.4)
        }
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
        if !muted { Task { await ramp(to: Self.volume, over: 0.6) } }
    }

    func stop() {
        fade?.cancel()
        player?.pause()
        player = nil
        current = nil
    }

    private func ramp(to target: Float, over span: Double) async {
        guard let player else { return }
        let from = player.volume
        let steps = max(1, Int(span * 30))
        for step in 1...steps {
            if Task.isCancelled { return }
            player.volume = from + (target - from) * Float(step) / Float(steps)
            try? await Task.sleep(nanoseconds: UInt64(span / Double(steps) * 1_000_000_000))
        }
    }
}
