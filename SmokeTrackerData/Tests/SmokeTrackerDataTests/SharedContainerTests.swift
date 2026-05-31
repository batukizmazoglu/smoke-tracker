import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct SharedContainerTests {
    @Test func fallsBackToDocumentsWhenAppGroupMissing() {
        // Sağlanmamış bir grup id → containerURL nil → Documents'a düşer,
        // ama dosya adı her durumda korunur.
        let url = SharedContainer.watchEventsURL(appGroup: "group.invalid.\(UUID().uuidString)")
        #expect(url.lastPathComponent == "watch-events.json")
    }
}
