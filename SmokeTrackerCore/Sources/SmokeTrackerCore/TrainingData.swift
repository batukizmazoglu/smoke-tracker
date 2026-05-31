import Foundation

/// Bir sensörlü seansta toplanan ham eğitim verisi (Faz 2 modeli için).
/// `eventID`, bu seansın ürettiği `SmokingEvent` ile bağ kurar.
public struct TrainingSession: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let eventID: UUID
    public let recordedAt: Date
    public let label: String
    public let samples: [MotionSample]

    public init(
        id: UUID,
        eventID: UUID,
        recordedAt: Date,
        label: String,
        samples: [MotionSample]
    ) {
        self.id = id
        self.eventID = eventID
        self.recordedAt = recordedAt
        self.label = label
        self.samples = samples
    }
}

/// Ham eğitim seanslarının kalıcı arşivi için soyutlama.
/// iPhone tarafında, kullanıcı izniyle saklanır; istendiğinde silinebilir.
///
/// NOT: Tek bir iş parçacığından/aktörden (uygulamada MainActor) kullanılmalıdır.
public protocol TrainingDataArchiving {
    func save(_ session: TrainingSession) throws
    func allSessions() -> [TrainingSession]
    func delete(id: UUID) throws
    func deleteAll() throws
}
