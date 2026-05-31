import Foundation
import SmokeTrackerCore

/// WCSession üzerinden taşınan sürümlü senkron mesajı.
public struct SyncMessage: Codable, Sendable {
    public let version: Int
    public let events: [SmokingEvent]

    public init(version: Int = 1, events: [SmokingEvent]) {
        self.version = version
        self.events = events
    }
}

/// Olay dizisini WCSession yükü (Data) ile kodlar/çözer.
public enum SyncMessageCodec {
    public static func encode(_ events: [SmokingEvent]) throws -> Data {
        try JSONEncoder().encode(SyncMessage(events: events))
    }

    public static func decode(_ data: Data) throws -> [SmokingEvent] {
        try JSONDecoder().decode(SyncMessage.self, from: data).events
    }
}
