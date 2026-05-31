import Foundation
import WatchConnectivity
import SmokeTrackerCore
import SmokeTrackerData

/// Yeni olayları WCSession ile iPhone'a güvenilir biçimde aktarır.
/// Yalnızca MainActor'daki WatchModel'den kullanılır.
@MainActor
final class WatchSyncSender: NSObject, WCSessionDelegate {
    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Tek bir olayı sıraya koyar; karşı taraf erişilemezse bile teslim edilir.
    func send(_ event: SmokingEvent) {
        guard let data = try? SyncMessageCodec.encode([event]) else { return }
        WCSession.default.transferUserInfo(["payload": data])
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
