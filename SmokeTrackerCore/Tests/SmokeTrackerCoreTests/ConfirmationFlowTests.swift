import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct ConfirmationFlowTests {
    private func candidate(start: TimeInterval = 100) -> PendingCandidate {
        let w = CandidateWindow(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: start + 60),
            samples: [MotionSample(timestamp: Date(timeIntervalSince1970: start), x: 1, y: 0, z: 0)],
            confidence: 0.5
        )
        return PendingCandidate(id: UUID(), detectedAt: Date(timeIntervalSince1970: start + 60), window: w)
    }

    @Test func smokedProducesEventAndPositiveTraining() {
        let c = candidate()
        let eventID = UUID(), trainingID = UUID()
        let r = ConfirmationFlow.outcome(for: c, result: .smoked, eventID: eventID, trainingID: trainingID)
        #expect(r.event?.id == eventID)
        #expect(r.event?.source == .autoConfirmed)
        #expect(r.event?.timestamp == c.window.start)
        #expect(r.training.label == TrainingLabel.smoking)
        #expect(r.training.eventID == eventID)
        #expect(r.training.recordedAt == c.window.start)
        #expect(r.training.samples == c.window.samples)
    }

    @Test func notSmokedProducesNegativeTrainingNoEvent() {
        let c = candidate()
        let r = ConfirmationFlow.outcome(for: c, result: .notSmoked, eventID: UUID(), trainingID: UUID())
        #expect(r.event == nil)
        #expect(r.training.label == TrainingLabel.notSmoking)
        #expect(r.training.samples == c.window.samples)
    }
}
