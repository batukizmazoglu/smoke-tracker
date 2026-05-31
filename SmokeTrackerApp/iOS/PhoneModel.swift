import Foundation
import Observation
import SwiftData
import SmokeTrackerCore
import SmokeTrackerData

/// iPhone tarafı durum: SwiftData ana deposu + istatistik + senkron alıcı.
@MainActor
@Observable
final class PhoneModel {
    let store: SwiftDataEventStore
    let coordinator: SyncCoordinator
    private let stats = StatsEngine(calendar: .current)
    private var receiver: PhoneSyncReceiver?

    var todayCount: Int = 0
    var weekCount: Int = 0
    var history: [SmokingEvent] = []

    init() {
        let container = try! EventStoreFactory.makePersistentContainer()
        let store = SwiftDataEventStore(context: ModelContext(container))
        self.store = store
        self.coordinator = SyncCoordinator(store: store)
        refresh()
        self.receiver = PhoneSyncReceiver(coordinator: coordinator) { [weak self] in
            self?.refresh()
        }
    }

    func refresh() {
        let all = store.allEvents()
        todayCount = stats.count(on: Date(), events: all)
        weekCount = stats.countInWeek(containing: Date(), events: all)
        history = all.sorted { $0.timestamp > $1.timestamp }
    }
}
