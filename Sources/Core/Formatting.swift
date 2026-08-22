import Foundation

enum Format {
    /// "2 h 15 min", "3 d 4 h" – never "2 h 60 min".
    static func duration(_ seconds: Int) -> String {
        var hours = seconds / 3600
        var minutes = Int((Double(seconds % 3600) / 60).rounded())
        if minutes == 60 { hours += 1; minutes = 0 }
        if hours >= 24 {
            return String(format: NSLocalizedString("%dd %dh", comment: ""),
                          hours / 24, hours % 24)
        }
        if hours > 0 {
            return String(format: NSLocalizedString("%dh %dm", comment: ""), hours, minutes)
        }
        return String(format: NSLocalizedString("%dm", comment: ""), minutes)
    }

    static func number(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func ago(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        if Date().timeIntervalSince(date) < 90 {
            return NSLocalizedString("just now", comment: "")
        }
        return date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }

    static func day(_ iso: String, long: Bool = false) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return iso }
        return long
            ? date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
            : date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func hour(_ hour: Int) -> String {
        String(format: NSLocalizedString("%d:00", comment: "hour of day"), hour)
    }

    static let weekdays: [String] = {
        let symbols = DateFormatter().shortWeekdaySymbols ?? []
        guard symbols.count == 7 else { return ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"] }
        // Rotation counts from Monday; DateFormatter starts at Sunday.
        return Array(symbols[1...6]) + [symbols[0]]
    }()

    static let months: [String] = {
        DateFormatter().shortMonthSymbols ?? []
    }()
}
