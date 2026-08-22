import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var session: Session
    @State private var lists: FriendLists?
    @State private var comparing: Person?
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Only people who added each other can see each other's statistics.")
                        .font(.footnote).foregroundStyle(.secondary)

                    if let lists {
                        if !lists.incoming.isEmpty {
                            section(String(localized: "Want to add you"), lists.incoming) { person in
                                Button(String(localized: "Confirm")) { Task { await add(person) } }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Palette.accent)
                            }
                        }
                        section(String(localized: "Your friends"), lists.friends,
                                empty: String(localized: "Nobody yet.")) { person in
                            Menu {
                                Button(String(localized: "View")) { session.viewing = person }
                                Button(String(localized: "Compare")) { comparing = person }
                                Button(String(localized: "Remove"), role: .destructive) {
                                    Task { await remove(person, withdraw: false) }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle").font(.title3)
                            }
                        }
                        if !lists.outgoing.isEmpty {
                            section(String(localized: "Requested"), lists.outgoing) { person in
                                Button(String(localized: "Withdraw")) {
                                    Task { await remove(person, withdraw: true) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        section(String(localized: "On this server"), lists.suggestions,
                                empty: String(localized: "Nobody else has opened Rotation yet.")) { person in
                            Button(String(localized: "Add")) { Task { await add(person) } }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Friends")
            .refreshable { await load() }
            .sheet(item: $comparing) { person in
                CompareView(friend: person).environmentObject(session)
            }
            .overlay(alignment: .bottom) {
                if let notice {
                    Text(notice)
                        .font(.footnote)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                        .task {
                            try? await Task.sleep(nanoseconds: 2_600_000_000)
                            self.notice = nil
                        }
                }
            }
        }
        .task { await load() }
    }

    private func section<Trailing: View>(
        _ title: String, _ people: [Person], empty: String? = nil,
        @ViewBuilder trailing: @escaping (Person) -> Trailing
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if people.isEmpty {
                if let empty {
                    Text(empty).font(.footnote).foregroundStyle(.tertiary)
                }
            } else {
                ForEach(people) { person in
                    HStack(spacing: 12) {
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(Palette.accent, in: Circle())
                        Text(person.name).font(.subheadline)
                        Spacer()
                        trailing(person)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func load() async {
        guard let source = session.source else { return }
        lists = await session.perform { try await source.friends() }
    }

    private func add(_ person: Person) async {
        guard let source = session.source else { return }
        let mutual = await session.perform { try await source.addFriend(person.id) } ?? false
        notice = mutual
            ? String(localized: "You are friends now.")
            : String(localized: "Requested – it becomes visible once they confirm.")
        await load()
    }

    private func remove(_ person: Person, withdraw: Bool) async {
        guard let source = session.source else { return }
        _ = await session.perform {
            try await source.removeFriend(person.id, withdraw: withdraw)
        }
        await load()
    }
}

/// Two people side by side, over a period of its own.
struct CompareView: View {
    let friend: Person
    @EnvironmentObject private var session: Session
    @Environment(\.dismiss) private var dismiss
    @State private var period: Period = .month
    @State private var data: Comparison?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PeriodPicker(period: $period)
                    if let data {
                        HStack(alignment: .top, spacing: 12) {
                            side(data.me, colour: Palette.accent)
                            Text("vs").font(.caption).foregroundStyle(.tertiary)
                                .padding(.top, 34)
                            side(data.them, colour: Palette.accentAlt)
                        }
                        if data.shared.isEmpty {
                            Text("No overlap in this period yet.")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Card(String(localized: "Artists you share")) {
                                VStack(spacing: 10) {
                                    legend(data)
                                    ForEach(data.shared) { entry in
                                        sharedRow(entry)
                                    }
                                }
                            }
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(friend.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
        .task(id: period.rawValue) {
            guard let source = session.source else { return }
            data = await session.perform {
                try await source.compare(with: friend.id, period: period)
            }
        }
    }

    private func side(_ person: ComparisonSide, colour: Color) -> some View {
        VStack(spacing: 4) {
            Text(person.user.name).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(Format.number(person.summary.plays))
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(colour)
            Text(String(localized: "Plays").uppercased())
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(Format.duration(person.summary.seconds))
                .font(.caption).foregroundStyle(.secondary)
            Text(String(format: String(localized: "%d artists"), person.summary.artists))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func legend(_ data: Comparison) -> some View {
        HStack(spacing: 16) {
            label(data.me.user.name, Palette.accent)
            label(data.them.user.name, Palette.accentAlt)
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func label(_ name: String, _ colour: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(colour).frame(width: 8, height: 8)
            Text(name)
        }
    }

    private func sharedRow(_ entry: SharedArtist) -> some View {
        HStack(spacing: 10) {
            Text(entry.name).font(.footnote).lineLimit(1)
                .frame(width: 96, alignment: .leading)
            GeometryReader { geometry in
                let total = CGFloat(max(entry.mine + entry.theirs, 1))
                HStack(spacing: 0) {
                    Rectangle().fill(Palette.accent)
                        .frame(width: geometry.size.width * CGFloat(entry.mine) / total)
                    Rectangle().fill(Palette.accentAlt)
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            Text("\(entry.mine) · \(entry.theirs)")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}
