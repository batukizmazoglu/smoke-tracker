import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct SyncMessageCodecTests {
    @Test func roundTripPreservesEvents() throws {
        let events = [
            SmokingEvent(id: UUID(), timestamp: Date(timeIntervalSince1970: 100), source: .tap),
            SmokingEvent(id: UUID(), timestamp: Date(timeIntervalSince1970: 200), source: .session),
        ]
        let data = try SyncMessageCodec.encode(events)
        let decoded = try SyncMessageCodec.decode(data)
        #expect(decoded == events)
    }

    @Test func decodingGarbageThrows() {
        let garbage = Data([0x00, 0x01, 0x02])
        #expect(throws: (any Error).self) {
            _ = try SyncMessageCodec.decode(garbage)
        }
    }

    @Test func encodesVersionField() throws {
        let data = try SyncMessageCodec.encode([])
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect((object?["version"] as? Int) == 1)
    }
}
