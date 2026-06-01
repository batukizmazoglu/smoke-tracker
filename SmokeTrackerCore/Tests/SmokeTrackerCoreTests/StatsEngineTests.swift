import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct StatsEngineTests {
    private func event(_ date: Date, _ source: EventSource = .tap) -> SmokingEvent {
        SmokingEvent(id: UUID(), timestamp: date, source: source)
    }

    @Test func countsEventsOnGivenDayRespectingTimeZone() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 31, 9, 0)),
            event(makeDate(2026, 5, 31, 14, 0)),
            event(makeDate(2026, 5, 31, 23, 30)),
            event(makeDate(2026, 6, 1, 0, 30)),   // ertesi gün (yerel)
        ]

        let count = engine.count(on: makeDate(2026, 5, 31, 12, 0), events: events)
        #expect(count == 3)
    }

    @Test func dailyCountsGroupsAndSortsAscending() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 6, 1, 0, 30)),
            event(makeDate(2026, 5, 31, 9, 0)),
            event(makeDate(2026, 5, 31, 14, 0)),
            event(makeDate(2026, 5, 31, 23, 30)),
        ]

        let daily = engine.dailyCounts(events: events)
        #expect(daily.count == 2)
        #expect(daily[0].count == 3)
        #expect(daily[1].count == 1)
        #expect(daily[0].day < daily[1].day)
    }

    @Test func countInWeekIncludesOnlySameWeek() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 25, 10, 0)), // Pazartesi
            event(makeDate(2026, 5, 27, 10, 0)),
            event(makeDate(2026, 5, 31, 23, 0)), // Pazar (aynı hafta)
            event(makeDate(2026, 6, 2, 10, 0)),  // sonraki hafta
        ]

        let count = engine.countInWeek(containing: makeDate(2026, 5, 27, 12, 0), events: events)
        #expect(count == 3)
    }

    @Test func emptyEventsYieldZero() {
        let engine = StatsEngine(calendar: makeCalendar())
        #expect(engine.count(on: makeDate(2026, 5, 31), events: []) == 0)
        #expect(engine.dailyCounts(events: []).isEmpty)
    }

    @Test func countInWeekExcludesExactWeekEndBoundary() {
        let engine = StatsEngine(calendar: makeCalendar())
        // Pazartesi 2026-06-01 00:00 (Istanbul) = sonraki haftanın başlangıcı,
        // yarı-açık hafta aralığının dışında kalmalı.
        let boundary = makeDate(2026, 6, 1, 0, 0)
        let events = [
            event(makeDate(2026, 5, 31, 23, 59)), // bu hafta
            event(boundary),                       // sonraki hafta (hariç)
        ]
        let count = engine.countInWeek(containing: makeDate(2026, 5, 27, 12, 0), events: events)
        #expect(count == 1)
    }

    // MARK: - dailyCounts(from:through:) — boşlukları sıfırla doldurur

    @Test func dailyCountsInRangeFillsGapsWithZero() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 30, 10, 0)),
            event(makeDate(2026, 6, 1, 8, 0)),
            event(makeDate(2026, 6, 1, 20, 0)),
        ]
        let daily = engine.dailyCounts(
            from: makeDate(2026, 5, 30, 0, 0),
            through: makeDate(2026, 6, 2, 23, 0),
            events: events
        )
        #expect(daily.count == 4)                     // 05-30, 05-31, 06-01, 06-02
        #expect(daily.map(\.count) == [1, 0, 2, 0])
        let cal = makeCalendar()
        #expect(daily[0].day == cal.startOfDay(for: makeDate(2026, 5, 30)))
        #expect(daily[3].day == cal.startOfDay(for: makeDate(2026, 6, 2)))
    }

    @Test func dailyCountsInRangeSingleDayCountsWholeDay() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 31, 9, 0)),
            event(makeDate(2026, 5, 31, 22, 0)),
        ]
        // Aralık gün bazlı: saat sınırları aynı güne düştüğü için ikisi de sayılır.
        let daily = engine.dailyCounts(
            from: makeDate(2026, 5, 31, 6, 0),
            through: makeDate(2026, 5, 31, 18, 0),
            events: events
        )
        #expect(daily.count == 1)
        #expect(daily[0].count == 2)
    }

    @Test func dailyCountsInRangeEmptyWhenFromAfterThrough() {
        let engine = StatsEngine(calendar: makeCalendar())
        let daily = engine.dailyCounts(
            from: makeDate(2026, 6, 2),
            through: makeDate(2026, 6, 1),
            events: []
        )
        #expect(daily.isEmpty)
    }

    // MARK: - dailyAverage

    @Test func dailyAverageOverTrackedSpan() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 30, 10, 0)),
            event(makeDate(2026, 5, 30, 12, 0)),
            event(makeDate(2026, 6, 1, 9, 0)),
        ]
        // span 05-30..06-01 = 3 gün, 3 olay → 1.0
        #expect(engine.dailyAverage(asOf: makeDate(2026, 6, 1, 23, 0), events: events) == 1.0)
    }

    @Test func dailyAverageEmptyIsZero() {
        let engine = StatsEngine(calendar: makeCalendar())
        #expect(engine.dailyAverage(asOf: makeDate(2026, 6, 1), events: []) == 0)
    }

    @Test func dailyAverageExcludesFutureEventsFromSpanAndCount() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 31, 10, 0)),
            event(makeDate(2026, 5, 31, 14, 0)),
            event(makeDate(2026, 6, 5, 10, 0)),    // asOf sonrası → ne sayılır ne span'i uzatır
        ]
        // asOf 05-31 → tek gün, 2 olay → 2.0
        #expect(engine.dailyAverage(asOf: makeDate(2026, 5, 31, 23, 0), events: events) == 2.0)
    }

    // MARK: - hourlyDistribution

    @Test func hourlyDistributionBucketsByLocalHour() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 31, 9, 0)),
            event(makeDate(2026, 5, 31, 9, 45)),
            event(makeDate(2026, 6, 1, 14, 0)),
            event(makeDate(2026, 6, 1, 23, 30)),
        ]
        let dist = engine.hourlyDistribution(events: events)
        #expect(dist.count == 24)
        #expect(dist[9] == 2)
        #expect(dist[14] == 1)
        #expect(dist[23] == 1)
        #expect(dist[0] == 0)
        #expect(dist.reduce(0, +) == 4)
    }

    // MARK: - daysSinceLastEvent

    @Test func daysSinceLastEventCountsCalendarDays() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 27, 8, 0)),
            event(makeDate(2026, 5, 29, 10, 0)),    // en son
        ]
        #expect(engine.daysSinceLastEvent(asOf: makeDate(2026, 6, 1, 9, 0), events: events) == 3)
    }

    @Test func daysSinceLastEventZeroWhenSameDay() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [event(makeDate(2026, 6, 1, 8, 0))]
        #expect(engine.daysSinceLastEvent(asOf: makeDate(2026, 6, 1, 22, 0), events: events) == 0)
    }

    @Test func daysSinceLastEventNilWhenNoEvents() {
        let engine = StatsEngine(calendar: makeCalendar())
        #expect(engine.daysSinceLastEvent(asOf: makeDate(2026, 6, 1), events: []) == nil)
    }

    // MARK: - count(inLastDays:)

    @Test func countInLastDaysIncludesInclusiveWindow() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 25, 12, 0)),   // 8 gün önce → dışarıda
            event(makeDate(2026, 5, 26, 0, 30)),   // pencere başı (7. gün) → içeride
            event(makeDate(2026, 6, 1, 23, 0)),    // bugün → içeride
            event(makeDate(2026, 6, 2, 1, 0)),     // gelecek → dışarıda
        ]
        let count = engine.count(inLastDays: 7, asOf: makeDate(2026, 6, 1, 12, 0), events: events)
        #expect(count == 2)
    }

    @Test func countInLastDaysSingleDayIsToday() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 31, 23, 0)),   // dün
            event(makeDate(2026, 6, 1, 1, 0)),     // bugün
        ]
        #expect(engine.count(inLastDays: 1, asOf: makeDate(2026, 6, 1, 12, 0), events: events) == 1)
    }
}
