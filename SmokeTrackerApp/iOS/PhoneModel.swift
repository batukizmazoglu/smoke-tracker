import Foundation
import Observation
import SwiftData
import SmokeTrackerCore
import SmokeTrackerData

/// iPhone tarafı durum: SwiftData ana deposu + istatistik + senkron alıcı +
/// eğitim verisi arşivi.
@MainActor
@Observable
final class PhoneModel {
    let store: SwiftDataEventStore
    let coordinator: SyncCoordinator
    let archive: FileTrainingDataArchive
    private let consent = UserDefaultsConsentStore()
    private let onboardingStore = UserDefaultsOnboardingStore()
    private var suppressConsentBroadcast = true   // init sırasında yayını bastır
    private let stats = StatsEngine(calendar: .current)
    private var receiver: PhoneSyncReceiver?

    var todayCount: Int = 0
    var weekCount: Int = 0
    var history: [SmokingEvent] = []
    var trainingSessions: [TrainingSession] = []
    var trainingDataConsent: Bool {
        didSet {
            consent.trainingDataConsent = trainingDataConsent
            guard !suppressConsentBroadcast else { return }
            receiver?.syncConsent(trainingDataConsent)
        }
    }
    var hasCompletedOnboarding: Bool

    init() {
        let container: ModelContainer
        do {
            container = try EventStoreFactory.makePersistentContainer()
        } catch {
            // Kalıcı depo bozuksa uygulama açılışta çökmesin diye bellek-içine düş.
            do {
                container = try EventStoreFactory.makeInMemoryContainer()
            } catch {
                fatalError("Bellek-içi ModelContainer oluşturulamadı: \(error)")
            }
        }
        let store = SwiftDataEventStore(context: ModelContext(container))
        let archiveDir = URL.documentsDirectory.appendingPathComponent("training", isDirectory: true)
        let archive = FileTrainingDataArchive(directory: archiveDir)

        self.store = store
        self.coordinator = SyncCoordinator(store: store)
        self.archive = archive
        self.trainingDataConsent = consent.trainingDataConsent
        self.hasCompletedOnboarding = onboardingStore.hasCompletedOnboarding
        refresh()
        self.receiver = PhoneSyncReceiver(
            coordinator: coordinator,
            archive: archive,
            onConsentChange: { [weak self] value in
                self?.applyRemoteConsent(value)
            },
            onChange: { [weak self] in
                self?.refresh()
            }
        )
        suppressConsentBroadcast = false
    }

    /// Watch'tan gelen onayı yerelde uygular; yeniden yayın yapmaz (döngü yok).
    func applyRemoteConsent(_ value: Bool) {
        guard value != trainingDataConsent else { return }
        suppressConsentBroadcast = true
        trainingDataConsent = value
        suppressConsentBroadcast = false
    }

    func refresh() {
        let all = store.allEvents()
        todayCount = stats.count(on: Date(), events: all)
        weekCount = stats.countInWeek(containing: Date(), events: all)
        history = all.sorted { $0.timestamp > $1.timestamp }
        trainingSessions = archive.allSessions().sorted { $0.recordedAt > $1.recordedAt }
    }

    func deleteTrainingSession(_ session: TrainingSession) {
        try? archive.delete(id: session.id)
        refresh()
    }

    func deleteAllTrainingData() {
        try? archive.deleteAll()
        refresh()
    }

    /// Onboarding'i tamamlandı olarak işaretler; kök ekran TodayView'a geçer.
    func completeOnboarding() {
        onboardingStore.hasCompletedOnboarding = true
        hasCompletedOnboarding = true
    }
}
