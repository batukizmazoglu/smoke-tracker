import Foundation

/// Tek bir sigara/IQOS olayının kaynağı.
public enum EventSource: String, Codable, Sendable, Equatable {
    case tap            // tek dokunuşla manuel kayıt
    case session        // sensörlü seanstan üretildi
    case autoConfirmed  // arka plan tespitinden onaylandı (Faz 2.1)
}

/// Tek bir sigara/IQOS olayı (1 olay = 1 çubuk).
public struct SmokingEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource

    public init(id: UUID, timestamp: Date, source: EventSource) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
    }
}
