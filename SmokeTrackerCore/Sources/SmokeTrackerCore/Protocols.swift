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
public protocol EventStoring {
    func allEvents() -> [SmokingEvent]
    func add(_ event: SmokingEvent)
    func contains(id: UUID) -> Bool
}
