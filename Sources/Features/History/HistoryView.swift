import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var session: Session
    @State private var overview: Overview?
    @State private var plays: [PlayEntry] = []
    @State private var detail: DetailTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let overview {
                        Card(String(localized: "Weekday and hour")) {
                            Heatmap(matrix: overview.clock.matrix)
                        }
                        Card(String(localized: "Longest streak")) {
                            HStack(spacing: 20) {
                                StatTile(value: "\(overview.streaks.current)",
                                         label: String(localized: "Current · days"), accent: true)
                                StatTile(value: "\(overview.streaks.longest)",
                                         label: String(localized: "Longest · days"))
                            }
                        }
                    }
                    Card(String(localized: "Recently played")) {
                        if plays.isEmpty {
                            Text("Nothing here for this period yet.")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(plays) { play in
                                    Button { detail = .track(play.trackID, Period.all.rawValue) } label: {
                                    HStack(spacing: 12) {
                                        Artwork(art: play.art, name: play.artist, size: 42)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(play.title).font(.subheadline).lineLimit(1)
                                            Text(play.artist).font(.caption)
                                                .foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer(minLength: 8)
                                        Text(Format.ago(play.playedAt))
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if play.id != plays.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
            .refreshable { await load() }
            .sheet(item: $detail) { target in
                DetailSheet(target: target).environmentObject(session)
            }
        }
        .task(id: session.viewing?.id ?? "me") { await load() }
    }

    private func load() async {
        guard let source = session.source else { return }
        let user = session.viewing?.id
        overview = await session.perform {
            try await source.overview(period: .all, user: user)
        }
        plays = await session.perform {
            try await source.recent(limit: 60, user: user)
        }?.plays ?? []
    }
}
