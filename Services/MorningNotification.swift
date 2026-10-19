import Foundation
import UserNotifications

/// Lokal morgonnotis (F11). Ingen server – iOS visar den varje dag på vald tid.
enum MorningNotification {
    static let identifier = "morning-shoe-reminder"
    /// 07:00, i minuter efter midnatt.
    static let defaultMinutes = 7 * 60

    static func makeRequest(minutesAfterMidnight: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.body = String(localized: "Dags att välja skor – öppna Skoväder")
        content.sound = .default

        var time = DateComponents()
        time.hour = minutesAfterMidnight / 60
        time.minute = minutesAfterMidnight % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    /// Sant om användaren tillåter notiser.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(minutesAfterMidnight: Int) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try await center.add(makeRequest(minutesAfterMidnight: minutesAfterMidnight))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
