import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct NotificationBudgetStoreTests {
    private final class StubDate: DateProviding {
        var value: Date
        init(_ value: Date) { self.value = value }
        func now() -> Date { value }
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "budget-\(UUID().uuidString)")!
    }

    @Test func sentTodayStartsAtZero() {
        let store = NotificationBudgetStore(defaults: defaults(),
                                            dateProvider: StubDate(Date(timeIntervalSince1970: 0)))
        #expect(store.sentToday() == 0)
    }

    @Test func recordSentIncrements() {
        let store = NotificationBudgetStore(defaults: defaults(),
                                            dateProvider: StubDate(Date(timeIntervalSince1970: 0)))
        store.recordSent()
        store.recordSent()
        #expect(store.sentToday() == 2)
    }

    @Test func countResetsOnNewDay() {
        let date = StubDate(Date(timeIntervalSince1970: 0))
        let store = NotificationBudgetStore(defaults: defaults(), dateProvider: date)
        store.recordSent()
        date.value = Date(timeIntervalSince1970: 0).addingTimeInterval(48 * 3600)
        #expect(store.sentToday() == 0)
    }
}
