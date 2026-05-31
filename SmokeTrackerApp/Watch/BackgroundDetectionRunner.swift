import Foundation
import CoreMotion
import SmokeTrackerCore
import SmokeTrackerData

/// Arka plan yenilemede çağrılır: sensör geçmişini çeker, adayları tespit eder,
/// pending olarak yazar ve (bütçeyle) onay bildirimi atar, sonra imleci ilerletir.
/// Yalnızca gerçek cihazda anlamlı veri akar (simülatörde boş döner).
@MainActor
struct BackgroundDetectionRunner {
    private let detector: SmokeDetecting
    private let pendingStore: PendingCandidateStore
    private let cursorStore: DetectionCursorStore
    private let budgetStore: NotificationBudgetStore
    private let recorder = CMSensorRecorder()

    private let maxLookback: TimeInterval = 30 * 60   // imleç yoksa son 30 dk
    private let pendingTTL: TimeInterval = 6 * 3600    // 6 saatten eski pending temizlenir

    init(detector: SmokeDetecting = HeuristicSmokeDetector(),
         pendingStore: PendingCandidateStore = PendingCandidateStore(url: SharedContainer.pendingCandidatesURL()),
         cursorStore: DetectionCursorStore = DetectionCursorStore(),
         budgetStore: NotificationBudgetStore = NotificationBudgetStore()) {
        self.detector = detector
        self.pendingStore = pendingStore
        self.cursorStore = cursorStore
        self.budgetStore = budgetStore
    }

    func run() {
        let now = Date()
        let cursor = cursorStore.cursor ?? now.addingTimeInterval(-maxLookback)
        let samples = pullSamples(from: cursor, to: now)
        let candidates = CandidateFilter.filter(detector.detect(in: samples), after: cursor)

        for window in candidates {
            let pending = PendingCandidate(id: UUID(), detectedAt: now, window: window)
            pendingStore.save(pending)
            SmokeNotificationScheduler.notifyIfAllowed(for: pending, budgetStore: budgetStore)
        }

        // Yanıtlanmamış eski adayları temizle.
        for old in pendingStore.all() where now.timeIntervalSince(old.detectedAt) > pendingTTL {
            pendingStore.remove(id: old.id)
        }

        cursorStore.cursor = now
    }

    private func pullSamples(from start: Date, to end: Date) -> [MotionSample] {
        guard let list = recorder.accelerometerData(from: start, to: end) else { return [] }
        var out: [MotionSample] = []
        for case let d as CMRecordedAccelerometerData in IteratorSequence(NSFastEnumerationIterator(list)) {
            out.append(MotionSample(timestamp: d.startDate,
                                    x: d.acceleration.x, y: d.acceleration.y, z: d.acceleration.z))
        }
        return out
    }
}
