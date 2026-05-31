import Foundation
import Testing
@testable import SmokeTrackerCore

// MARK: - Paylaşılan test yardımcıları

/// Sabit bir tarih döndüren DateProviding gerçeklemesi.
final class FixedDateProvider: DateProviding {
    var fixed: Date
    init(_ fixed: Date) { self.fixed = fixed }
    func now() -> Date { fixed }
}

/// Bellek içi EventStoring gerçeklemesi.
final class InMemoryEventStore: EventStoring {
    private(set) var events: [SmokingEvent] = []
    func allEvents() -> [SmokingEvent] { events }
    func add(_ event: SmokingEvent) { events.append(event) }
    func contains(id: UUID) -> Bool { events.contains { $0.id == id } }
}

/// Belirli bir zaman dilimi ve takvimde deterministik tarih üretir.
func makeDate(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int = 12, _ minute: Int = 0,
    timeZone: TimeZone = TimeZone(identifier: "Europe/Istanbul")!
) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    return cal.date(from: comps)!
}

/// İstatistik testleri için Pazartesi-başlangıçlı, sabit zaman dilimli takvim.
func makeCalendar(
    timeZone: TimeZone = TimeZone(identifier: "Europe/Istanbul")!
) -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    cal.firstWeekday = 2 // Pazartesi
    return cal
}

// MARK: - Yardımcıların kendi testi

@Suite struct TestHelpersTests {
    @Test func inMemoryStoreAddsAndDeduplicatesLookup() {
        let store = InMemoryEventStore()
        let id = UUID()
        let event = SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31), source: .tap)

        #expect(store.contains(id: id) == false)
        store.add(event)
        #expect(store.contains(id: id) == true)
        #expect(store.allEvents().count == 1)
    }

    @Test func fixedDateProviderReturnsFixedValue() {
        let d = makeDate(2026, 5, 31, 9, 0)
        let provider = FixedDateProvider(d)
        #expect(provider.now() == d)
    }
}
