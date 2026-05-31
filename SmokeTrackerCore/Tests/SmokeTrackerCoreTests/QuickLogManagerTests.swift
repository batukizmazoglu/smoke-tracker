import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct QuickLogManagerTests {
    @Test func logOneCreatesTapEventWithProviderValues() {
        let store = InMemoryEventStore()
        let fixedDate = makeDate(2026, 5, 31, 9, 0)
        let fixedID = UUID()
        let manager = QuickLogManager(
            store: store,
            dateProvider: FixedDateProvider(fixedDate),
            idProvider: { fixedID }
        )

        let event = manager.logOne()

        #expect(event.id == fixedID)
        #expect(event.timestamp == fixedDate)
        #expect(event.source == .tap)
        #expect(store.allEvents().count == 1)
        #expect(store.allEvents().first == event)
    }

    @Test func multipleLogsAccumulate() {
        let store = InMemoryEventStore()
        var counter = 0
        let manager = QuickLogManager(
            store: store,
            dateProvider: FixedDateProvider(makeDate(2026, 5, 31, 9, 0)),
            idProvider: {
                counter += 1
                return UUID(uuidString: "00000000-0000-0000-0000-00000000000\(counter)")!
            }
        )

        manager.logOne()
        manager.logOne()
        manager.logOne()

        #expect(store.allEvents().count == 3)
    }
}
