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
public struct StatsEngine: Sendable {
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
    /// Aralık yarı-açıktır `[start, end)`: hafta bitiş anı (sonraki haftanın
    /// başlangıcı) hariç tutulur, böylece her olay tek bir haftaya ait olur.
    /// (Not: `DateInterval.contains` her iki ucu da dahil ettiğinden burada
    /// kullanılmaz; aksi halde sınır anı iki haftada birden sayılırdı.)
    public func countInWeek(containing date: Date, events: [SmokingEvent]) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return events.filter { $0.timestamp >= interval.start && $0.timestamp < interval.end }.count
    }

    /// `[from, through]` aralığındaki her gün için sayım — olay olmayan günler
    /// sıfır olarak doldurulur, sonuç artan sırada. Grafik gibi süreklilik
    /// bekleyen görünümlerde boşlukların görsel olarak temsil edilmesini sağlar.
    /// `from`, `through`'dan sonraysa boş döner.
    public func dailyCounts(from: Date, through: Date, events: [SmokingEvent]) -> [DailyCount] {
        let startDay = calendar.startOfDay(for: from)
        let endDay = calendar.startOfDay(for: through)
        guard startDay <= endDay else { return [] }

        var countsByDay: [Date: Int] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.timestamp)
            if day >= startDay && day <= endDay {
                countsByDay[day, default: 0] += 1
            }
        }

        var result: [DailyCount] = []
        var cursor = startDay
        while cursor <= endDay {
            result.append(DailyCount(day: cursor, count: countsByDay[cursor] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// İlk olaydan `asOf` gününe kadarki takip süresi boyunca gün başına ortalama
    /// olay sayısı. `asOf` gününden sonraki olaylar ne sayıma ne de süreye katılır.
    /// Hiç (uygun) olay yoksa 0.
    public func dailyAverage(asOf: Date, events: [SmokingEvent]) -> Double {
        let asOfDay = calendar.startOfDay(for: asOf)
        let relevant = events.filter { calendar.startOfDay(for: $0.timestamp) <= asOfDay }
        guard let earliest = relevant.map({ calendar.startOfDay(for: $0.timestamp) }).min() else { return 0 }
        let spanDays = (calendar.dateComponents([.day], from: earliest, to: asOfDay).day ?? 0) + 1
        guard spanDays > 0 else { return 0 }
        return Double(relevant.count) / Double(spanDays)
    }

    /// Saat dilimine (yerel) göre 0–23 arası 24 kovalı olay dağılımı.
    /// Günün hangi saatlerinde yoğunlaşıldığını gösteren grafikler için.
    public func hourlyDistribution(events: [SmokingEvent]) -> [Int] {
        var buckets = Array(repeating: 0, count: 24)
        for event in events {
            let hour = calendar.component(.hour, from: event.timestamp)
            if hour >= 0 && hour < 24 { buckets[hour] += 1 }
        }
        return buckets
    }

    /// `asOf` gününe kadarki en son olaydan bu yana geçen tam takvim günü sayısı.
    /// Aynı gün için 0, hiç olay yoksa `nil`. `asOf`'tan sonraki olaylar yok sayılır.
    public func daysSinceLastEvent(asOf: Date, events: [SmokingEvent]) -> Int? {
        let asOfDay = calendar.startOfDay(for: asOf)
        let lastDay = events
            .filter { $0.timestamp <= asOf }
            .map { calendar.startOfDay(for: $0.timestamp) }
            .max()
        guard let lastDay else { return nil }
        return calendar.dateComponents([.day], from: lastDay, to: asOfDay).day
    }

    /// `asOf` gününde biten son `days` gün (dahil) içindeki olay sayısı.
    /// `days == 1` yalnızca `asOf` gününü kapsar; `days < 1` ise 0.
    public func count(inLastDays days: Int, asOf: Date, events: [SmokingEvent]) -> Int {
        guard days >= 1 else { return 0 }
        let asOfDay = calendar.startOfDay(for: asOf)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: asOfDay),
              let start = calendar.date(byAdding: .day, value: -(days - 1), to: asOfDay) else { return 0 }
        return events.filter { $0.timestamp >= start && $0.timestamp < endExclusive }.count
    }
}
