import Foundation

/// Eğitim verisi etiketleri. Pozitif: gerçekten içildi; negatif: içilmedi.
public enum TrainingLabel {
    public static let smoking = "sigara"
    public static let notSmoking = "sigara_degil"
}

/// Kullanıcının onay cevabı.
public enum ConfirmationResult: Sendable, Equatable {
    case smoked
    case notSmoked
}

/// Onay bekleyen adayların kalıcı deposu (gerçeklemesi Data'da).
public protocol PendingCandidateStoring: AnyObject {
    func save(_ candidate: PendingCandidate)
    func all() -> [PendingCandidate]
    func remove(id: UUID)
}

/// Onay cevabını, üretilecek olay + eğitim seansına eşleyen saf mantık.
public enum ConfirmationFlow {
    public static func outcome(
        for candidate: PendingCandidate,
        result: ConfirmationResult,
        eventID: UUID,
        trainingID: UUID
    ) -> (event: SmokingEvent?, training: TrainingSession) {
        let window = candidate.window
        switch result {
        case .smoked:
            let event = SmokingEvent(id: eventID, timestamp: window.start, source: .autoConfirmed)
            let training = TrainingSession(id: trainingID, eventID: eventID,
                                           recordedAt: window.start, label: TrainingLabel.smoking,
                                           samples: window.samples)
            return (event, training)
        case .notSmoked:
            // Olay yok; eventID yalnızca seansa sentetik kimlik verir.
            let training = TrainingSession(id: trainingID, eventID: eventID,
                                           recordedAt: window.start, label: TrainingLabel.notSmoking,
                                           samples: window.samples)
            return (nil, training)
        }
    }
}
