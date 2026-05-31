import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct TapThrottleTests {
    @Test func firstTapIsAccepted() {
        let throttle = TapThrottle(minInterval: 2)
        #expect(throttle.accept(at: Date(timeIntervalSince1970: 100)) == true)
    }

    @Test func secondTapWithinIntervalIsRejected() {
        let throttle = TapThrottle(minInterval: 2)
        _ = throttle.accept(at: Date(timeIntervalSince1970: 100))
        #expect(throttle.accept(at: Date(timeIntervalSince1970: 101)) == false)
    }

    @Test func tapAtIntervalBoundaryIsAccepted() {
        let throttle = TapThrottle(minInterval: 2)
        _ = throttle.accept(at: Date(timeIntervalSince1970: 100))
        #expect(throttle.accept(at: Date(timeIntervalSince1970: 102)) == true)
    }
}
