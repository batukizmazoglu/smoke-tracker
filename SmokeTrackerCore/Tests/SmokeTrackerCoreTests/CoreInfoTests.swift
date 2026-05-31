import Testing
@testable import SmokeTrackerCore

@Suite struct CoreInfoTests {
    @Test func exposesVersion() {
        #expect(CoreInfo.version == "0.1.0")
    }
}
