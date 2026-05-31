import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct TrainingSessionCodecTests {
    @Test func encodeDecodeRoundTripPreservesSession() throws {
        let session = TrainingSession(
            id: UUID(),
            eventID: UUID(),
            recordedAt: Date(timeIntervalSince1970: 500),
            label: "sigara",
            samples: [
                MotionSample(timestamp: Date(timeIntervalSince1970: 500), x: 0.1, y: 0.2, z: 0.3),
                MotionSample(timestamp: Date(timeIntervalSince1970: 501), x: 1, y: 2, z: 3)
            ]
        )

        let data = try TrainingSessionCodec.encode(session)
        let decoded = try TrainingSessionCodec.decode(data)

        #expect(decoded == session)
    }
}
