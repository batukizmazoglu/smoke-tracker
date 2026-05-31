import Foundation
import WatchConnectivity
import SmokeTrackerCore
import SmokeTrackerData

/// Watch'tan gelen olayları (userInfo) ve eğitim verisini (file) alır.
/// iPhone tarafındaki tek WCSession delegate'i. Delegate çağrıları arka planda
/// gelir; işleme MainActor'a taşınır.
@MainActor
final class PhoneSyncReceiver: NSObject, WCSessionDelegate {
    private let coordinator: SyncCoordinator
    private let archive: TrainingDataArchiving
    private let onConsentChange: (Bool) -> Void
    private let onChange: () -> Void

    init(
        coordinator: SyncCoordinator,
        archive: TrainingDataArchiving,
        onConsentChange: @escaping (Bool) -> Void,
        onChange: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.archive = archive
        self.onConsentChange = onConsentChange
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

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // fileURL yalnızca bu çağrı süresince geçerlidir; hemen oku ve çöz.
        guard let data = try? Data(contentsOf: file.fileURL),
              let training = try? TrainingSessionCodec.decode(data) else { return }
        Task { @MainActor in
            try? self.archive.save(training)
            self.onChange()
        }
    }

    /// Yerel (onboarding/ayar) onay değişimini watch'a taşır.
    func syncConsent(_ on: Bool) {
        guard WCSession.isSupported() else { return }
        try? WCSession.default.updateApplicationContext(
            ConsentSyncCodec.encode(trainingDataConsent: on)
        )
    }

    /// Watch'tan gelen onay durumunu çöz ve MainActor'da PhoneModel'e ilet.
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let value = ConsentSyncCodec.decode(applicationContext) else { return }
        Task { @MainActor in
            self.onConsentChange(value)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
