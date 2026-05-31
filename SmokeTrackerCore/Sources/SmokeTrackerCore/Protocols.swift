import Foundation

/// Şu anki zamanı sağlayan soyutlama (test edilebilirlik için).
public protocol DateProviding {
    func now() -> Date
}

/// Gerçek sistem saatini kullanan varsayılan sağlayıcı.
public struct SystemDateProvider: DateProviding {
    public init() {}
    public func now() -> Date { Date() }
}

/// Sigara olaylarının kalıcı deposu için soyutlama.
/// Plan 2'de SwiftData ile gerçeklenecek.
///
/// Sözleşme: `add(_:)` ile eklenen bir olay, aynı senkron bağlamda hemen
/// ardından çağrılan `contains(id:)` tarafından görülebilir olmalıdır.
/// Yazımları tamponlayan (ör. işlem/transaction kullanan) gerçeklemeler
/// `add(_:)` dönmeden önce bunu yansıtmalıdır; aksi halde `SyncCoordinator`
/// aynı toplu istek içindeki tekrarları eleyemez.
public protocol EventStoring {
    func allEvents() -> [SmokingEvent]
    func add(_ event: SmokingEvent)
    func contains(id: UUID) -> Bool
}
