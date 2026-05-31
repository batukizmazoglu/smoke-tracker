import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct HeuristicSmokeDetectorTests {
    private func sample(_ t: TimeInterval, burst: Bool) -> MotionSample {
        MotionSample(timestamp: Date(timeIntervalSince1970: t), x: burst ? 2 : 0, y: 0, z: 0)
    }

    /// `count` adet burst üretir; her burst, yükselen kenar için bir "rest"
    /// örneğiyle başlar ve tam saniyede zirve yapar.
    private func bursts(start: TimeInterval, count: Int, step: TimeInterval) -> [MotionSample] {
        var s: [MotionSample] = []
        for i in 0..<count {
            let t = start + Double(i) * step
            s.append(sample(t - 0.5, burst: false))
            s.append(sample(t, burst: true))
        }
        return s
    }

    @Test func flatSignalYieldsNoCandidate() {
        let s = (0..<10).map { sample(Double($0), burst: false) }
        #expect(HeuristicSmokeDetector().detect(in: s).isEmpty)
    }

    @Test func belowMinBurstsYieldsNoCandidate() {
        #expect(HeuristicSmokeDetector().detect(in: bursts(start: 0, count: 3, step: 2)).isEmpty)
    }

    @Test func clusterOfFourYieldsOneCandidate() {
        let result = HeuristicSmokeDetector().detect(in: bursts(start: 0, count: 4, step: 2))
        #expect(result.count == 1)
        #expect(result.first?.start == Date(timeIntervalSince1970: 0))
        #expect(result.first?.end == Date(timeIntervalSince1970: 6))
        #expect(result.first?.confidence == 0.5)
        #expect(result.first?.samples.isEmpty == false)
    }

    @Test func twoSeparatedClustersYieldTwoCandidates() {
        let s = bursts(start: 0, count: 4, step: 2) + bursts(start: 200, count: 4, step: 2)
        #expect(HeuristicSmokeDetector().detect(in: s).count == 2)
    }

    @Test func isolatedSpikesAreIgnored() {
        let s = [0.0, 200, 400, 600].flatMap { bursts(start: $0, count: 1, step: 1) }
        #expect(HeuristicSmokeDetector().detect(in: s).isEmpty)
    }

    @Test func confidenceCapsAtOne() {
        let result = HeuristicSmokeDetector().detect(in: bursts(start: 0, count: 10, step: 2))
        #expect(result.first?.confidence == 1.0)
    }
}
