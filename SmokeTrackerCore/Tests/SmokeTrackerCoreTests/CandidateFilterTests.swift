import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct CandidateFilterTests {
    private func win(_ start: TimeInterval, _ end: TimeInterval) -> CandidateWindow {
        CandidateWindow(start: Date(timeIntervalSince1970: start),
                        end: Date(timeIntervalSince1970: end),
                        samples: [], confidence: 1)
    }

    @Test func dropsCandidatesAtOrBeforeCursor() {
        let r = CandidateFilter.filter([win(10, 20), win(30, 40)],
                                       after: Date(timeIntervalSince1970: 25))
        #expect(r.map(\.start) == [Date(timeIntervalSince1970: 30)])
    }

    @Test func dropsOverlappingCandidate() {
        let r = CandidateFilter.filter([win(10, 50), win(20, 60)],
                                       after: Date(timeIntervalSince1970: 0))
        #expect(r.count == 1)
        #expect(r.first?.start == Date(timeIntervalSince1970: 10))
    }

    @Test func keepsDisjointCandidates() {
        let r = CandidateFilter.filter([win(10, 20), win(30, 40)],
                                       after: Date(timeIntervalSince1970: 0))
        #expect(r.count == 2)
    }
}
