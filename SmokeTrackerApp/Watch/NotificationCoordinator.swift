import Foundation
import UserNotifications
import SmokeTrackerCore

/// Bildirim aksiyonlarını (Evet/Hayır) WatchModel'e ileten tek
/// UNUserNotificationCenter delegate'i. (WCSession delegate'i ayrı —
/// WatchSyncSender; çakışma yok.)
@MainActor
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    var onConfirm: ((UUID, ConfirmationResult) -> Void)?

    // Swift 6: nonisolated bağlamda MainActor-isolated static'lere erişilemez;
    // string sabitleri burada kopyalanır (kaynak SmokeNotificationScheduler).
    private nonisolated let _candidateKey = "candidateID"
    private nonisolated let _yesAction   = "SMOKE_YES"
    private nonisolated let _noAction    = "SMOKE_NO"

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let idString = info[_candidateKey] as? String
        let action = response.actionIdentifier
        // completionHandler nonisolated bağlamda çağrılır (Swift 6 data race yok).
        Task { @MainActor in
            if let idString, let id = UUID(uuidString: idString) {
                switch action {
                case self._yesAction: self.onConfirm?(id, .smoked)
                case self._noAction:  self.onConfirm?(id, .notSmoked)
                default: break   // gövdeye dokunma / kapatma → işlem yok
                }
            }
        }
        completionHandler()
    }

    /// Uygulama ön plandayken de bildirimi göster.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
