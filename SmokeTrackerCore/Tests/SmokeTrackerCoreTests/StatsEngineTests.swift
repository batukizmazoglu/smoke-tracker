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
}
