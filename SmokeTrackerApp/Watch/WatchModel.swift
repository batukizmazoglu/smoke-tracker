import Foundation
import Observation
import SmokeTrackerCore
import SmokeTrackerData

/// Watch tarafı durum: yerel kayıt, bugünkü sayı, +1 ve opsiyonel sensörlü seans.
@MainActor
@Observable
final class WatchModel {
    private let store: FileEventStore
    private let quickLog: QuickLogManager
    private let sender: WatchSyncSender
    private let stats = StatsEngine(calendar: .current)
    private let consent: UserDefaultsConsentStore
    private let motionRecorder: AccelerometerMotionRecorder
    private let sessionRecorder: SessionRecorder

    var todayCount: Int = 0
    var isRecordingSession: Bool = false
    var trainingDataConsent: Bool {
        didSet { consent.trainingDataConsent = trainingDataConsent }
    }

    init() {
        let url = URL.documentsDirectory.appendingPathComponent("watch-events.json")
        let store = FileEventStore(url: url)
        let consent = UserDefaultsConsentStore()
        let motionRecorder = AccelerometerMotionRecorder()

        self.store = store
        self.quickLog = QuickLogManager(store: store, dateProvider: SystemDateProvider())
        self.sender = WatchSyncSender()
        self.consent = consent
        self.motionRecorder = motionRecorder
        self.sessionRecorder = SessionRecorder(motion: motionRecorder, dateProvider: SystemDateProvider())
        self.trainingDataConsent = consent.trainingDataConsent
        refresh()
    }

    /// +1: yerelde kaydet, iPhone'a gönder, sayıyı güncelle.
    func logOne() {
        let event = quickLog.logOne()
        sender.send(event)
        refresh()
    }

    /// Sensörlü seansı başlatır (ilk kayıt Motion iznini tetikler).
    func startSession() {
        sessionRecorder.start()
        isRecordingSession = true
    }

    /// Seansı bitirir: her zaman +1 işler; izin varsa ham veriyi iPhone'a yollar.
    func stopSession() {
        guard let result = sessionRecorder.stop() else { return }
        isRecordingSession = false

        // Olay kanalı (her zaman): +1 say ve iPhone'a gönder.
        store.add(result.event)
        sender.send(result.event)

        // Eğitim verisi kanalı (yalnızca izinle, en iyi-çaba).
        if trainingDataConsent, !result.samples.isEmpty {
            let training = TrainingSession(
                id: UUID(),
                eventID: result.event.id,
                recordedAt: result.event.timestamp,
                label: "sigara",
                samples: result.samples
            )
            sender.sendTrainingSession(training)
        }
        refresh()
    }

    func refresh() {
        todayCount = stats.count(on: Date(), events: store.allEvents())
    }
}
