import Foundation

/// Tek dokunuşla anında +1 kaydı oluşturur (kaynak: .tap).
///
/// Bu sınıf Watch tarafındaki tek yazardır; `SyncCoordinator` ise iPhone
/// tarafındaki tek yazardır. Her ikisi benzersiz `id` ürettiğinden çakışmaz.
/// Aynı dokunuşun iki kez kaydedilmesini önlemek (debounce) UI katmanının
/// sorumluluğundadır (bkz. complication, Plan 3).
public final class QuickLogManager {
    private let store: EventStoring
    private let dateProvider: DateProviding
    private let idProvider: () -> UUID

    public init(
        store: EventStoring,
        dateProvider: DateProviding,
        idProvider: @escaping () -> UUID = { UUID() }
    ) {
        self.store = store
        self.dateProvider = dateProvider
        self.idProvider = idProvider
    }

    /// Yeni bir tap olayı oluşturup depoya ekler ve döndürür.
    @discardableResult
    public func logOne() -> SmokingEvent {
        let event = SmokingEvent(
            id: idProvider(),
            timestamp: dateProvider.now(),
            source: .tap
        )
        store.add(event)
        return event
    }
}
