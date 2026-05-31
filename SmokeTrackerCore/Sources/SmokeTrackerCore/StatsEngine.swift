import Foundation

/// Bir günün toplam sayısı.
public struct DailyCount: Equatable, Sendable {
    public let day: Date   // günün başlangıcı (startOfDay)
    public let count: Int

    public init(day: Date, count: Int) {
        self.day = day
        self.count = count
    }
}

/// Olay listesinden günlük/haftalık sayımlar üreten saf hesaplayıcı.
public struct StatsEngine {
    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// Verilen güne (yerel takvime göre) ait olay sayısı.
    public func count(on day: Date, events: [SmokingEvent]) -> Int {
        events.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.count
    }

    /// Olayları güne göre gruplayıp artan sırada döndürür.
    public func dailyCounts(events: [SmokingEvent]) -> [DailyCount] {
        let groups = Dictionary(grouping: events) { calendar.startOfDay(for: $0.timestamp) }
        return groups
            .map { DailyCount(day: $0.key, count: $0.value.count) }
            .sorted { $0.day < $1.day }
    }

    /// Verilen tarihin içinde bulunduğu haftanın toplam sayısı.
    public func countInWeek(containing date: Date, events: [SmokingEvent]) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return events.filter { interval.contains($0.timestamp) }.count
    }
}
