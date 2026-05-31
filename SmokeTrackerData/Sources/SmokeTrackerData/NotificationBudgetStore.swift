import Foundation
import SmokeTrackerCore

/// Bugün gönderilen onay bildirimi sayısını tutar; takvim günü değişince
/// otomatik sıfırlanır. Gün anahtarı yerel takvime göre hesaplanır.
public final class NotificationBudgetStore {
    private let defaults: UserDefaults
    private let dateProvider: DateProviding
    private let countKey = "notif_sent_count"
    private let dayKey = "notif_sent_day"

    public init(defaults: UserDefaults = .standard, dateProvider: DateProviding = SystemDateProvider()) {
        self.defaults = defaults
        self.dateProvider = dateProvider
    }

    public func sentToday() -> Int {
        guard defaults.string(forKey: dayKey) == currentDayKey() else { return 0 }
        return defaults.integer(forKey: countKey)
    }

    public func recordSent() {
        let today = currentDayKey()
        if defaults.string(forKey: dayKey) != today {
            defaults.set(today, forKey: dayKey)
            defaults.set(0, forKey: countKey)
        }
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
    }

    private func currentDayKey() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: dateProvider.now())
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
