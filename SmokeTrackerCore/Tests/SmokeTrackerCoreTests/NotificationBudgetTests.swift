import Testing
@testable import SmokeTrackerCore

@Suite struct NotificationBudgetTests {
    @Test func allowsUnderCapDuringActiveHours() {
        #expect(NotificationBudget.canNotify(sentToday: 0, hour: 12, config: BudgetConfig()) == true)
    }

    @Test func blocksAtDailyCap() {
        #expect(NotificationBudget.canNotify(sentToday: 10, hour: 12, config: BudgetConfig()) == false)
    }

    @Test func blocksDuringQuietHours() {
        #expect(NotificationBudget.canNotify(sentToday: 0, hour: 2, config: BudgetConfig()) == false)
        #expect(NotificationBudget.canNotify(sentToday: 0, hour: 23, config: BudgetConfig()) == false)
    }

    @Test func allowsAtQuietEndBoundary() {
        // quietEndHour(7) hariç → 07:xx artık sessiz değil
        #expect(NotificationBudget.canNotify(sentToday: 0, hour: 7, config: BudgetConfig()) == true)
    }
}
