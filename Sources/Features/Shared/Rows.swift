import SwiftUI

/// One line of a top list: rank, artwork, name, count – and a bar that shows
/// the share at a glance.
struct TopRow: View {
    let rank: Int
    let title: String
    let subtitle: String
    let art: String?
    let plays: Int
    let share: Double
    var rounded = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 11) {
                Text("\(rank)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 18, alignment: .trailing)
                Artwork(art: art, name: title, size: 40, rounded: rounded)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(Format.number(plays))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.accent.opacity(0.55))
                    .frame(width: max(2, geometry.size.width * share), height: 2)
            }
            .frame(height: 2)
        }
        // Without this a tap only counts on the letters themselves; the gaps
        // between artwork, name and number would do nothing.
        .contentShape(Rectangle())
    }
}

/// A card, the way every screen in Rotation uses one.
/// Something a card offers next to its title – used by the playlist button
/// over the top tracks.
struct CardAction {
    let title: String
    var busy = false
    var secondary: String?
    let run: () async -> Void
    var runSecondary: (() async -> Void)?
}

struct Card<Content: View>: View {
    let title: String?
    let action: CardAction?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, action: CardAction? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || action != nil {
                // On a small screen, or with the system font turned up, the
                // three of them do not fit on one line – so they stack.
                ViewThatFits(in: .horizontal) {
                    header(oneLine: true)
                    header(oneLine: false)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func header(oneLine: Bool) -> some View {
        let layout = oneLine
            ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        layout {
            if let title {
                Text(title).font(.subheadline.weight(.semibold))
            }
            if oneLine { Spacer(minLength: 0) }
            if let action {
                HStack(spacing: 10) {
                    if let secondary = action.secondary,
                       let runSecondary = action.runSecondary {
                        Button(secondary) { Task { await runSecondary() } }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await action.run() }
                    } label: {
                        if action.busy {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(action.title).font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(action.busy)
                }
            }
        }
    }
}

/// The headline numbers above the fold.
struct StatTile: View {
    let value: String
    let label: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.heavy))
                .foregroundStyle(accent ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.primary))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct PeriodPicker: View {
    @Binding var period: Period

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Period.allCases) { option in
                    Button {
                        period = option
                    } label: {
                        Text(option.label)
                            .font(.footnote.weight(period == option ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(period == option
                                        ? AnyShapeStyle(Palette.accent)
                                        : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                            .foregroundStyle(period == option ? .black : .secondary)
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
