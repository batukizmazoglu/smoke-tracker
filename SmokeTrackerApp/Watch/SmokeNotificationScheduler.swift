import Foundation
import UserNotifications
import SmokeTrackerCore
import SmokeTrackerData

/// "Sigara içtin mi?" onay bildirimini kurar ve (bütçe izniyle) gönderir.
@MainActor
enum SmokeNotificationScheduler {
    nonisolated static let categoryID = "SMOKE_CONFIRM"
    nonisolated static let yesAction = "SMOKE_YES"
    nonisolated static let noAction = "SMOKE_NO"
    nonisolated static let candidateKey = "candidateID"

    /// Evet/Hayır aksiyonlu kategoriyi kaydeder (açılışta bir kez).
    static func registerCategory() {
        let yes = UNNotificationAction(identifier: yesAction, title: "Evet", options: [])
        let no = UNNotificationAction(identifier: noAction, title: "Hayır", options: [])
        let category = UNNotificationCategory(identifier: categoryID, actions: [yes, no],
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Bildirim iznini ister; reddedilirse özellik sessizce devre dışı kalır.
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Bütçe izin veriyorsa aday için onay bildirimi planlar; gönderirse true.
    @discardableResult
    static func notifyIfAllowed(
        for candidate: PendingCandidate,
        budgetStore: NotificationBudgetStore,
        config: BudgetConfig = BudgetConfig()
    ) -> Bool {
        let hour = Calendar.current.component(.hour, from: candidate.detectedAt)
        guard NotificationBudget.canNotify(sentToday: budgetStore.sentToday(),
                                           hour: hour, config: config) else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Sigara içtin mi?"
        let time = candidate.window.start.formatted(date: .omitted, time: .shortened)
        content.body = "~\(time) civarında bir hareket fark ettik."
        content.categoryIdentifier = categoryID
        content.userInfo = [candidateKey: candidate.id.uuidString]

        let request = UNNotificationRequest(identifier: candidate.id.uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        budgetStore.recordSent()
        return true
    }
}
