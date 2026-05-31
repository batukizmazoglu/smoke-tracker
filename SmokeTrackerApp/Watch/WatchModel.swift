import Foundation
import Observation
import WidgetKit
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
    private let complicationThrottle = TapThrottle(minInterval: 2)
    private var suppressConsentBroadcast = true   // init sırasında yayını bastır

    var todayCount: Int = 0
    var isRecordingSession: Bool = false
    var motionStatus: MotionPermissionStatus = .notDetermined
    var trainingDataConsent: Bool {
        didSet {
            consent.trainingDataConsent = trainingDataConsent
            guard !suppressConsentBroadcast else { return }
            sender.syncConsent(trainingDataConsent)
        }
    }

    init() {
        // Olay deposu, complication ile paylaşılan App Group konteynerinde.
        let store = FileEventStore(url: SharedContainer.watchEventsURL())
        let consent = UserDefaultsConsentStore()
        let motionRecorder = AccelerometerMotionRecorder()

        self.store = store
        self.quickLog = QuickLogManager(store: store, dateProvider: SystemDateProvider())
        self.sender = WatchSyncSender()
        self.consent = consent
        self.motionRecorder = motionRecorder
        self.sessionRecorder = SessionRecorder(motion: motionRecorder, dateProvider: SystemDateProvider())
        self.motionStatus = WatchMotionAuthorizer.status
        self.trainingDataConsent = consent.trainingDataConsent
        self.sender.onConsentChange = { [weak self] value in
            self?.applyRemoteConsent(value)
        }
        refresh()
        suppressConsentBroadcast = false
    }

    /// iPhone'dan gelen onayı yerelde uygular; yeniden yayın yapmaz (döngü yok).
    func applyRemoteConsent(_ value: Bool) {
        guard value != trainingDataConsent else { return }
        suppressConsentBroadcast = true
        trainingDataConsent = value   // store'a yazılır, tekrar yayınlanmaz
        suppressConsentBroadcast = false
    }

    /// +1: yerelde kaydet, iPhone'a gönder, sayıyı ve complication'ı güncelle.
    func logOne() {
        let event = quickLog.logOne()
        sender.send(event)
        refresh()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Complication'dan gelen +1; çok kısa aralıkta tekrarları eler.
    func logFromComplication() {
        guard complicationThrottle.accept(at: Date()) else { return }
        logOne()
    }

    /// Sensörlü seansı başlatır (ilk kayıt Motion iznini tetikler). İzin kalıcı
    /// kapalıysa seans açılmaz; +1 yine de çalışır.
    func startSession() {
        motionStatus = WatchMotionAuthorizer.status
        guard SessionAvailability.canStartSession(motion: motionStatus) else { return }
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
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Motion izin durumunu güncel CMSensorRecorder yetkisinden tazeler.
    func refreshMotionStatus() {
        motionStatus = WatchMotionAuthorizer.status
    }

    /// Kullanıcı isteğiyle Motion iznini proaktif tetikler, sonra durumu tazeler.
    func requestMotionPermission() {
        motionRecorder.requestAuthorization()
        refreshMotionStatus()
    }

    func refresh() {
        todayCount = stats.count(on: Date(), events: store.allEvents())
    }
}
