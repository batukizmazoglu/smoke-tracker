import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct DetectionCursorStoreTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "cursor-\(UUID().uuidString)")!
    }

    @Test func cursorDefaultsToNil() {
        #expect(DetectionCursorStore(defaults: defaults()).cursor == nil)
    }

    @Test func cursorPersists() {
        let store = DetectionCursorStore(defaults: defaults())
        let d = Date(timeIntervalSince1970: 12345)
        store.cursor = d
        #expect(store.cursor == d)
    }
}
