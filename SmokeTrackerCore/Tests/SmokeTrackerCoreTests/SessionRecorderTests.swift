import Testing
import Foundation
@testable import SmokeTrackerCore

/// Önceden tanımlı örnekler döndüren sahte MotionRecording.
final class MockMotionRecorder: MotionRecording {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    var samplesToReturn: [MotionSample]

    init(samplesToReturn: [MotionSample] = []) {
        self.samplesToReturn = samplesToReturn
    }

    func startRecording() { startCallCount += 1 }
    func stopRecording() -> [MotionSample] {
        stopCallCount += 1
        return samplesToReturn
    }
}

@Suite struct SessionRecorderTests {
    private func sample(_ t: Double) -> MotionSample {
        MotionSample(timestamp: Date(timeIntervalSince1970: t), x: 0.1, y: 0.2, z: 0.3)
    }

    @Test func startsRecordingFromIdle() {
        let motion = MockMotionRecorder()
        let recorder = SessionRecorder(
            motion: motion,
            dateProvider: FixedDateProvider(makeDate(2026, 5, 31, 9, 0))
        )

        #expect(recorder.state == .idle)
        recorder.start()
        #expect(recorder.state == .recording)
        #expect(motion.startCallCount == 1)
    }

    @Test func stopProducesSessionEventAndSamples() {
        let samples = [sample(1), sample(2)]
        let motion = MockMotionRecorder(samplesToReturn: samples)
        let fixedDate = makeDate(2026, 5, 31, 9, 0)
        let fixedID = UUID()
        let recorder = SessionRecorder(
            motion: motion,
            dateProvider: FixedDateProvider(fixedDate),
            idProvider: { fixedID }
        )

        recorder.start()
        let result = recorder.stop()

        #expect(recorder.state == .finished)
        #expect(motion.stopCallCount == 1)
        #expect(result?.event.id == fixedID)
        #expect(result?.event.timestamp == fixedDate)
        #expect(result?.event.source == .session)
        #expect(result?.samples == samples)
    }

    @Test func startIsNoOpWhenAlreadyRecording() {
        let motion = MockMotionRecorder()
        let recorder = SessionRecorder(
            motion: motion,
            dateProvider: FixedDateProvider(makeDate(2026, 5, 31, 9, 0))
        )

        recorder.start()
        recorder.start()

        #expect(motion.startCallCount == 1)
        #expect(recorder.state == .recording)
    }

    @Test func stopReturnsNilWhenIdle() {
        let motion = MockMotionRecorder()
        let recorder = SessionRecorder(
            motion: motion,
            dateProvider: FixedDateProvider(makeDate(2026, 5, 31, 9, 0))
        )

        let result = recorder.stop()

        #expect(result == nil)
        #expect(motion.stopCallCount == 0)
        #expect(recorder.state == .idle)
    }

    @Test func canStartNewSessionAfterFinished() {
        let motion = MockMotionRecorder()
        let recorder = SessionRecorder(
            motion: motion,
            dateProvider: FixedDateProvider(makeDate(2026, 5, 31, 9, 0))
        )

        recorder.start()
        _ = recorder.stop()
        #expect(recorder.state == .finished)

        recorder.start()
        #expect(recorder.state == .recording)
        #expect(motion.startCallCount == 2)
    }
}
