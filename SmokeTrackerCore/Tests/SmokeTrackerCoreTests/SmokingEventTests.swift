import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct SmokingEventTests {
    @Test func storesProvidedValues() {
        let id = UUID()
        let ts = Date(timeIntervalSince1970: 1_700_000_000)
        let event = SmokingEvent(id: id, timestamp: ts, source: .tap)

        #expect(event.id == id)
        #expect(event.timestamp == ts)
        #expect(event.source == .tap)
    }

    @Test func isCodableRoundTrip() throws {
        let event = SmokingEvent(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            source: .session
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(SmokingEvent.self, from: data)
        #expect(decoded == event)
    }

    @Test func autoConfirmedSourceRoundTrips() throws {
        let event = SmokingEvent(id: UUID(),
                                 timestamp: Date(timeIntervalSince1970: 100),
                                 source: .autoConfirmed)
        #expect(event.source.rawValue == "autoConfirmed")
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(SmokingEvent.self, from: data)
        #expect(decoded == event)
    }
}
