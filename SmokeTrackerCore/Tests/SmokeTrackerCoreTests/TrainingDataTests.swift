import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct TrainingDataTests {
    @Test func trainingSessionRoundTripsThroughCodable() throws {
        let sample = MotionSample(
            timestamp: Date(timeIntervalSince1970: 100),
            x: 0.1, y: -0.2, z: 9.8
        )
        let session = TrainingSession(
            id: UUID(),
            eventID: UUID(),
            recordedAt: Date(timeIntervalSince1970: 200),
            label: "sigara",
            samples: [sample]
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(TrainingSession.self, from: data)

        #expect(decoded == session)
    }
}
