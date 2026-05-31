import Foundation
import WatchConnectivity
import SmokeTrackerCore
import SmokeTrackerData

/// Watch'tan gelen olayları alır ve SyncCoordinator ile ana depoya işler.
/// WCSession delegate çağrıları arka planda gelir; deposu MainActor'da olduğu
/// için işleme MainActor'a taşınır.
@MainActor
final class PhoneSyncReceiver: NSObject, WCSessionDelegate {
    private let coordinator: SyncCoordinator
    private let onChange: () -> Void

    init(coordinator: SyncCoordinator, onChange: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onChange = onChange
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["payload"] as? Data,
              let events = try? SyncMessageCodec.decode(data) else { return }
        Task { @MainActor in
            for event in events {
                self.coordinator.ingest(event)
            }
            self.onChange()
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
