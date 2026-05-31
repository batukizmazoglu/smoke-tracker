import Foundation
import WatchConnectivity
import SmokeTrackerCore
import SmokeTrackerData

/// Yeni olayları ve (izinle) eğitim verisini WCSession ile iPhone'a aktarır.
/// Watch tarafındaki tek WCSession delegate'i; yalnızca MainActor'daki
/// WatchModel'den kullanılır.
@MainActor
final class WatchSyncSender: NSObject, WCSessionDelegate {
    /// iPhone'dan applicationContext ile gelen onay değişimini WatchModel'e
    /// iletir. WatchModel init'te atar.
    var onConsentChange: ((Bool) -> Void)?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
    }

    /// WCSession'ı etkinleştirir. `onConsentChange` gibi callback'ler
    /// bağlandıktan SONRA çağrılmalı; aksi halde aktivasyon anında teslim
    /// edilebilen ilk applicationContext (onay durumu) kaçabilir.
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.activate()
    }

    /// Tek bir olayı sıraya koyar; karşı taraf erişilemezse bile teslim edilir.
    func send(_ event: SmokingEvent) {
        guard let data = try? SyncMessageCodec.encode([event]) else { return }
        WCSession.default.transferUserInfo(["payload": data])
    }

    /// Ham eğitim verisini dosya olarak gönderir (boyut büyük olabilir).
    func sendTrainingSession(_ session: TrainingSession) {
        guard let data = try? TrainingSessionCodec.encode(session) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("training-\(session.id.uuidString).json")
        do {
            try data.write(to: url, options: .atomic)
            WCSession.default.transferFile(url, metadata: ["type": "trainingSession"])
        } catch {
            #if DEBUG
            print("[WatchSyncSender] eğitim verisi yazılamadı: \(error)")
            #endif
        }
    }

    /// Yerel onay değişimini iPhone'a taşır. applicationContext son durumu tutar;
    /// karşı taraf uyandığında teslim alır (latest-wins).
    func syncConsent(_ on: Bool) {
        guard WCSession.isSupported() else { return }
        try? WCSession.default.updateApplicationContext(
            ConsentSyncCodec.encode(trainingDataConsent: on)
        )
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    /// iPhone'dan gelen onay durumunu çöz ve MainActor'da WatchModel'e ilet.
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let value = ConsentSyncCodec.decode(applicationContext) else { return }
        Task { @MainActor in
            self.onConsentChange?(value)
        }
    }

    /// Dosya transferi bitince (başarılı ya da hatalı) yarattığımız geçici
    /// dosyayı sil; aksi halde her seansta tmp dizini büyür.
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
    }
}
