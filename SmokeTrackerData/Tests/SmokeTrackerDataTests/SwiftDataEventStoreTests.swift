import Testing
import Foundation
import SwiftData
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct SwiftDataEventStoreTests {
    private func makeStore() throws -> SwiftDataEventStore {
        let container = try EventStoreFactory.makeInMemoryContainer()
        return SwiftDataEventStore(context: ModelContext(container))
    }

    private func event(_ id: UUID = UUID(), _ ts: Date = Date(timeIntervalSince1970: 1_700_000_000), _ source: EventSource = .tap) -> SmokingEvent {
        SmokingEvent(id: id, timestamp: ts, source: source)
    }

    @Test func addThenAllEventsReturnsIt() throws {
        let store = try makeStore()
        let e = event()
        store.add(e)
        let all = store.allEvents()
        #expect(all.count == 1)
        #expect(all.first == e)
    }

    @Test func containsReflectsAddedEvent() throws {
        let store = try makeStore()
        let id = UUID()
        #expect(store.contains(id: id) == false)
        store.add(event(id))
        #expect(store.contains(id: id) == true)
    }

    @Test func duplicateIdIsNotStoredTwice() throws {
        let store = try makeStore()
        let id = UUID()
        store.add(event(id, Date(timeIntervalSince1970: 1)))
        store.add(event(id, Date(timeIntervalSince1970: 2)))
        #expect(store.allEvents().count == 1)
    }

    @Test func eventsAreReturnedSortedByTimestamp() throws {
        let store = try makeStore()
        store.add(event(UUID(), Date(timeIntervalSince1970: 300)))
        store.add(event(UUID(), Date(timeIntervalSince1970: 100)))
        store.add(event(UUID(), Date(timeIntervalSince1970: 200)))
        let times = store.allEvents().map { $0.timestamp.timeIntervalSince1970 }
        #expect(times == [100, 200, 300])
    }
}
