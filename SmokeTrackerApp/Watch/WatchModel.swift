import Foundation
import Observation
import SmokeTrackerCore
import SmokeTrackerData

/// Watch tarafı durum: yerel kayıt + bugünkü sayı + gönderim.
@MainActor
@Observable
final class WatchModel {
    private let store: FileEventStore
    private let quickLog: QuickLogManager
    private let sender: WatchSyncSender
    private let stats = StatsEngine(calendar: .current)

    var todayCount: Int = 0

    init() {
        let url = URL.documentsDirectory.appendingPathComponent("watch-events.json")
        let store = FileEventStore(url: url)
        self.store = store
        self.quickLog = QuickLogManager(store: store, dateProvider: SystemDateProvider())
        self.sender = WatchSyncSender()
        refresh()
    }

    /// +1: yerelde kaydet, iPhone'a gönder, sayıyı güncelle.
    func logOne() {
        let event = quickLog.logOne()
        sender.send(event)
        refresh()
    }

    private func refresh() {
        todayCount = stats.count(on: Date(), events: store.allEvents())
    }
}
