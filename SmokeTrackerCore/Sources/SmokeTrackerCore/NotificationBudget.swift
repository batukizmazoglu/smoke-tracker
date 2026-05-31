import Foundation

/// Bildirim bütçesi ayarları. Başlangıç: günde 10, 23:00–07:00 sessiz.
public struct BudgetConfig: Sendable {
    public let dailyCap: Int
    public let quietStartHour: Int   // dahil
    public let quietEndHour: Int     // hariç

    public init(dailyCap: Int = 10, quietStartHour: Int = 23, quietEndHour: Int = 7) {
        self.dailyCap = dailyCap
        self.quietStartHour = quietStartHour
        self.quietEndHour = quietEndHour
    }
}

/// Onay bildirimi gönderilebilir mi? Saf politika.
public enum NotificationBudget {
    public static func canNotify(sentToday: Int, hour: Int, config: BudgetConfig) -> Bool {
        guard sentToday < config.dailyCap else { return false }
        return !isQuiet(hour: hour, config: config)
    }

    static func isQuiet(hour: Int, config: BudgetConfig) -> Bool {
        if config.quietStartHour <= config.quietEndHour {
            return hour >= config.quietStartHour && hour < config.quietEndHour
        } else {
            // Gece yarısını saran aralık (ör. 23..7).
            return hour >= config.quietStartHour || hour < config.quietEndHour
        }
    }
}
