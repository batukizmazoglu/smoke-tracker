import Foundation

/// Watch'tan gelen olayları ana depoya idempotent biçimde aktarır.
/// Aynı `id`'li olay birden çok kez gelse bile tek kez saklanır.
public final class SyncCoordinator {
    private let store: EventStoring

    public init(store: EventStoring) {
        self.store = store
    }

    /// Tek olayı alır. Yeni eklendiyse `true`, zaten varsa `false` döner.
    @discardableResult
    public func ingest(_ event: SmokingEvent) -> Bool {
        guard !store.contains(id: event.id) else { return false }
        store.add(event)
        return true
    }

    /// Olay dizisini sırayla alır; tekrarları otomatik eler.
    public func ingest(_ events: [SmokingEvent]) {
        for event in events {
            ingest(event)
        }
    }
}
