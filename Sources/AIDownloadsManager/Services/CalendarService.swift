import Foundation
import EventKit

/// "Add to Calendar" — always an explicit user action (a button tap on one
/// record), never automatic for every detected date.
enum CalendarService {
    private static let store = EKEventStore()

    static func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Creates a calendar event on the record's date with an alarm N days
    /// before it. Returns the created event's identifier (stored on the
    /// record so a future "remove" or "already added" check is possible).
    @discardableResult
    static func addEvent(for record: ExpiryRecord, alarmDaysBefore: Int) throws -> String {
        let event = EKEvent(eventStore: store)
        event.title = "\(record.title) — \(record.eventType.displayName)"
        event.notes = record.sourceText
        event.startDate = record.date
        event.endDate = record.date.addingTimeInterval(3600)
        event.isAllDay = true
        if alarmDaysBefore > 0 {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-alarmDaysBefore * 86400)))
        }
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }
}
