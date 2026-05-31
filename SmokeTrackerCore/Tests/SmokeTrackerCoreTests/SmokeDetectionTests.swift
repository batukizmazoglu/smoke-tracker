import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct SmokeDetectionTests {
    @Test func candidateWindowRoundTrips() throws {
        let w = CandidateWindow(
            start: Date(timeIntervalSince1970: 1),
            end: Date(timeIntervalSince1970: 2),
            samples: [MotionSample(timestamp: Date(timeIntervalSince1970: 1), x: 1, y: 2, z: 3)],
            confidence: 0.75
        )
        let data = try JSONEncoder().encode(w)
        #expect(try JSONDecoder().decode(CandidateWindow.self, from: data) == w)
    }

    @Test func pendingCandidateRoundTrips() throws {
        let w = CandidateWindow(
            start: Date(timeIntervalSince1970: 1),
            end: Date(timeIntervalSince1970: 2),
            samples: [],
            confidence: 0.5
        )
        let p = PendingCandidate(id: UUID(), detectedAt: Date(timeIntervalSince1970: 3), window: w)
        let data = try JSONEncoder().encode(p)
        #expect(try JSONDecoder().decode(PendingCandidate.self, from: data) == p)
    }
}
