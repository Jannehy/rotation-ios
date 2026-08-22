import Foundation
import UserNotifications

/// The one notification Rotation sends: your recap is ready.
///
/// Scheduled locally and repeating yearly, so it arrives on the first of
/// December whether or not the app has been opened since – and without any
/// push server, which a self-hosted statistics app has no business running.
enum SeasonReminder {
    private static let identifier = "rotation.season"

    /// Asks once, and schedules only if the answer was yes.
    static func enable() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        let granted = (try? await centre.requestAuthorization(options: [.alert, .sound]))
            ?? false
        if granted { await schedule() } else { cancel() }
        return granted
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Called at every start. The reminder is on by default, so the first
    /// launch is where the system is asked – once, and never again if the
    /// answer was no or the switch has since been turned off.
    static func refreshIfAllowed(wanted: Bool) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            if wanted { await schedule() } else { cancel() }
        case .notDetermined:
            if wanted { _ = await enable() }
        default:
            break
        }
    }

    private static func schedule() async {
        let content = UNMutableNotificationContent()
        // The year is not in the text: a repeating notification is written
        // once and delivered for years, and a stale year would be worse than
        // none at all.
        content.title = String(localized: "Your recap is here")
        content.body = String(localized: "Your year in music is waiting.")
        content.sound = .default

        var when = DateComponents()
        when.month = 12
        when.day = 1
        when.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)

        let request = UNNotificationRequest(identifier: identifier,
                                            content: content, trigger: trigger)
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await centre.add(request)
    }
}
