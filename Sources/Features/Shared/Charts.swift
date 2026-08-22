import Charts
import SwiftUI


/// Plays per day, with a read-out that follows the finger.
///
/// The read-out sits *above* the chart and moves with the selected point:
/// underneath it would be exactly where the thumb is.
struct TimelineChart: View {
    let days: [DayEntry]
    @State private var selected: Int?
    @State private var pointX: CGFloat = 0
    @State private var captionWidth: CGFloat = 0

    private struct WidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    var body: some View {
        GeometryReader { outer in
            VStack(spacing: 0) {
                caption(width: outer.size.width)
                    .frame(height: 26, alignment: .bottom)

                Chart {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        AreaMark(x: .value("Day", index), y: .value("Plays", day.plays))
                            .foregroundStyle(
                                LinearGradient(colors: [Palette.accent.opacity(0.38), .clear],
                                               startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", index), y: .value("Plays", day.plays))
                            .foregroundStyle(Palette.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    if let selected, days.indices.contains(selected) {
                        PointMark(x: .value("Day", selected),
                                  y: .value("Plays", days[selected].plays))
                            .foregroundStyle(Palette.accent)
                            .symbolSize(90)
                        RuleMark(x: .value("Day", selected))
                            .foregroundStyle(.secondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0, max(0, days.count - 1)]) { value in
                        AxisValueLabel {
                            if let index = value.as(Int.self), days.indices.contains(index) {
                                Text(Format.day(days[index].date))
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .trackTouches(onMove: { location in
                                let plot = geometry[proxy.plotAreaFrame]
                                let x = location.x - plot.origin.x
                                guard let index: Int = proxy.value(atX: x) else { return }
                                let clamped = min(max(index, 0), days.count - 1)
                                selected = clamped
                                if let position = proxy.position(forX: clamped) {
                                    pointX = position + plot.origin.x
                                }
                            }, onEnd: { selected = nil })
                    }
                }
            }
        }
        .frame(height: 176)
    }

    @ViewBuilder
    private func caption(width: CGFloat) -> some View {
        if let selected, days.indices.contains(selected) {
            let day = days[selected]
            let plays = String(format: NSLocalizedString("%d plays", comment: ""), day.plays)
            // Centred on the point, but never pushed off either edge.
            let offset = min(max(pointX - captionWidth / 2, 0), max(width - captionWidth, 0))
            Text("\(Format.day(day.date, long: true)) · \(plays)")
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .background(GeometryReader { measure in
                    Color.clear.preference(key: WidthKey.self, value: measure.size.width)
                })
                .onPreferenceChange(WidthKey.self) { captionWidth = $0 }
                .offset(x: offset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        } else {
            Color.clear
        }
    }
}

/// The hours of the day drawn as a record: each spoke one hour.
struct RecordClock: View {
    let clock: ClockInfo
    @State private var selected: Int?

    private var hour: Int? { selected ?? clock.peakHour }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let centre = CGPoint(x: geometry.size.width / 2, y: side / 2)
                let outer = side * 0.40
                let inner = side * 0.16
                let peak = max(clock.hours.max() ?? 1, 1)

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        .frame(width: outer * 2, height: outer * 2)
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        .frame(width: inner * 2, height: inner * 2)

                    ForEach(0..<24, id: \.self) { index in
                        let value = clock.hours.indices.contains(index) ? clock.hours[index] : 0
                        let fraction = Double(value) / Double(peak)
                        Path { path in
                            let angle = Double(index) / 24 * 2 * .pi - .pi / 2
                            let length = inner + (outer - inner) * fraction
                            path.move(to: CGPoint(x: centre.x + cos(angle) * inner,
                                                  y: centre.y + sin(angle) * inner))
                            path.addLine(to: CGPoint(x: centre.x + cos(angle) * length,
                                                     y: centre.y + sin(angle) * length))
                        }
                        .stroke(Palette.accent.opacity(hour == index ? 1 : 0.25 + fraction * 0.7),
                                style: StrokeStyle(lineWidth: side * 0.026, lineCap: .round))
                    }

                    ForEach([0, 3, 6, 9, 12, 15, 18, 21], id: \.self) { mark in
                        let angle = Double(mark) / 24 * 2 * .pi - .pi / 2
                        Text("\(mark)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .position(x: centre.x + cos(angle) * (outer + side * 0.055),
                                      y: centre.y + sin(angle) * (outer + side * 0.055))
                    }

                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: side * 0.035, height: side * 0.035)
                        .position(centre)
                }
                .contentShape(Rectangle())
                // Round chart: reading it means moving in every direction, so
                // it waits for a press instead of a sideways swipe.
                .trackTouchesAfterLongPress(onMove: { location in
                    let dx = location.x - centre.x
                    let dy = location.y - centre.y
                    var angle = atan2(dy, dx) + .pi / 2
                    if angle < 0 { angle += 2 * .pi }
                    selected = Int((angle / (2 * .pi) * 24).rounded()) % 24
                }, onEnd: { selected = nil })
            }
            .frame(height: 230)

            Text(caption)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(height: 16)
        }
    }

    private var caption: String {
        guard let hour, clock.hours.indices.contains(hour) else { return "" }
        let plays = String(format: NSLocalizedString("%d plays", comment: ""), clock.hours[hour])
        return "\(Format.hour(hour)) · \(plays)"
    }
}

/// Weekday against hour of day.
struct Heatmap: View {
    let matrix: [[Int]]

    private var peak: Int { max(matrix.flatMap { $0 }.max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<min(matrix.count, 7), id: \.self) { day in
                HStack(spacing: 2) {
                    Text(Format.weekdays.indices.contains(day) ? Format.weekdays[day] : "")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 26, alignment: .trailing)
                    ForEach(0..<24, id: \.self) { hour in
                        let value = matrix[day].indices.contains(hour) ? matrix[day][hour] : 0
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(value == 0
                                  ? Color.secondary.opacity(0.10)
                                  : Palette.accent.opacity(0.18 + Double(value) / Double(peak) * 0.82))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            // Four labels, each six columns wide – one per column has no
            // room for a two-digit hour.
            HStack(spacing: 2) {
                Color.clear.frame(width: 26, height: 1)
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text("\(hour)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// The twelve months of a Wrapped year.
struct MonthBars: View {
    let months: [MonthEntry]
    @Binding var selected: Int?

    private var peak: Int { max(months.map(\.plays).max() ?? 1, 1) }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(months) { month in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Palette.accent.opacity(selected == month.month ? 1 : 0.55))
                            .frame(height: max(3, geometry.size.height
                                               * CGFloat(month.plays) / CGFloat(peak)))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: geometry.size.height, alignment: .bottom)
                .contentShape(Rectangle())
                .trackTouches(onMove: { location in
                    let ratio = location.x / max(geometry.size.width, 1)
                    selected = min(12, max(1, Int(ratio * 12) + 1))
                })
            }
            .frame(height: 110)

            HStack(spacing: 4) {
                ForEach(Array(Format.months.enumerated()), id: \.offset) { _, name in
                    Text(String(name.prefix(1)))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
