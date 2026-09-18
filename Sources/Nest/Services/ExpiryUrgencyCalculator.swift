import Foundation

/// Configurable time windows that turn "days remaining" into an urgency
/// bucket. Deliberately not hard-coded colors/labels — just day thresholds.
struct ExpiryUrgencyWindows: Codable {
    var criticalDays: Int = 7
    var soonDays: Int = 30
    var upcomingDays: Int = 90

    static let `default` = ExpiryUrgencyWindows()

    private static let key = "expiryUrgencyWindows"

    static func loadFromDefaults() -> ExpiryUrgencyWindows {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ExpiryUrgencyWindows.self, from: data) else {
            return .default
        }
        return decoded
    }

    func saveToDefaults() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

enum ExpiryUrgencyCalculator {
    static func daysRemaining(until date: Date, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
    }

    static func urgency(for date: Date, windows: ExpiryUrgencyWindows = .default, now: Date = Date()) -> ExpiryUrgency {
        let days = daysRemaining(until: date, now: now)
        if days < 0 { return .expired }
        if days <= windows.criticalDays { return .critical }
        if days <= windows.soonDays { return .soon }
        if days <= windows.upcomingDays { return .upcoming }
        return .future
    }
}
