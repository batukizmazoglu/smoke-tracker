import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct SyncCoordinatorTests {
    @Test func ingestsNewEvent() {
        let store = InMemoryEventStore()
        let coordinator = SyncCoordinator(store: store)
        let event = SmokingEvent(id: UUID(), timestamp: makeDate(2026, 5, 31), source: .tap)

        let inserted = coordinator.ingest(event)

        #expect(inserted == true)
        #expect(store.allEvents().count == 1)
    }

    @Test func ignoresDuplicateId() {
        let store = InMemoryEventStore()
        let coordinator = SyncCoordinator(store: store)
        let id = UUID()
        let first = SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31, 9, 0), source: .tap)
        let dup = SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31, 9, 1), source: .tap)

        #expect(coordinator.ingest(first) == true)
        #expect(coordinator.ingest(dup) == false)
        #expect(store.allEvents().count == 1)
    }

    @Test func ingestBatchDeduplicates() {
        let store = InMemoryEventStore()
        let coordinator = SyncCoordinator(store: store)
        let id = UUID()
        let batch = [
            SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31, 9, 0), source: .tap),
            SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31, 9, 0), source: .tap),
            SmokingEvent(id: UUID(), timestamp: makeDate(2026, 5, 31, 10, 0), source: .tap),
        ]

        coordinator.ingest(batch)

        #expect(store.allEvents().count == 2)
    }
}
