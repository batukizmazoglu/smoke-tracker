import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct FileEventStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("fes-\(UUID().uuidString).json")
    }

    private func event(_ id: UUID = UUID(), _ t: Double = 100) -> SmokingEvent {
        SmokingEvent(id: id, timestamp: Date(timeIntervalSince1970: t), source: .tap)
    }

    @Test func addStoresEventInMemory() {
        let store = FileEventStore(url: tempURL())
        let e = event()
        store.add(e)
        #expect(store.allEvents() == [e])
    }

    @Test func persistsAcrossInstancesAtSameURL() {
        let url = tempURL()
        let e = event()
        let first = FileEventStore(url: url)
        first.add(e)

        let second = FileEventStore(url: url)
        #expect(second.allEvents() == [e])
    }

    @Test func deduplicatesById() {
        let url = tempURL()
        let id = UUID()
        let store = FileEventStore(url: url)
        store.add(event(id, 1))
        store.add(event(id, 2))
        #expect(store.allEvents().count == 1)
    }

    @Test func emptyWhenFileMissing() {
        let store = FileEventStore(url: tempURL())
        #expect(store.allEvents().isEmpty)
        #expect(store.contains(id: UUID()) == false)
    }
}
