import Foundation
import UserNotifications

/// Local macOS notifications for expiry/deadline records. Never sends
/// anything anywhere — everything is scheduled and delivered on-device via
/// UNUserNotificationCenter.
enum ExpiryNotificationService {
    private static let identifierPrefix = "expiry."

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Clears every expiry-related notification this app previously scheduled,
    /// then re-schedules from scratch based on current records + settings.
    /// Safe to call often — it's idempotent and cheap.
    static func reschedule(records: [ExpiryRecord], offsetDays: Set<Int>, notifyOnExpiry: Bool, onlyHighConfidence: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        for record in records {
            guard record.userStatus == .active, record.eventType.isTimeSensitive else { continue }
            if onlyHighConfidence && record.confidence < ExpiryRecord.reviewConfidenceThreshold { continue }

            for days in offsetDays {
                guard let fireDate = Calendar.current.date(byAdding: .day, value: -days, to: record.date),
                      fireDate > Date() else { continue }
                schedule(center: center, record: record, fireDate: fireDate, body: "\(record.title) \(record.eventType.displayName.lowercased()) in \(days) day\(days == 1 ? "" : "s").", suffix: "d\(days)")
            }

            if notifyOnExpiry, record.date > Date() {
                schedule(center: center, record: record, fireDate: record.date, body: "\(record.title) \(record.eventType.displayName.lowercased()) today.", suffix: "today")
            }
        }
    }

    private static func schedule(center: UNUserNotificationCenter, record: ExpiryRecord, fireDate: Date, body: String, suffix: String) {
        let content = UNMutableNotificationContent()
        content.title = "AI Downloads Manager"
        content.body = body
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 9 // a reasonable, non-intrusive local time
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "\(identifierPrefix)\(record.id.uuidString).\(suffix)", content: content, trigger: trigger)
        center.add(request)
    }
}
