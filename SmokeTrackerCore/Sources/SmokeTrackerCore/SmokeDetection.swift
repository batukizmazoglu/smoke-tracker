import Foundation

/// Bir arka plan partisinde tespit edilen, onaya değer hareket penceresi.
public struct CandidateWindow: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let samples: [MotionSample]
    public let confidence: Double   // 0...1 heuristik güven skoru

    public init(start: Date, end: Date, samples: [MotionSample], confidence: Double) {
        self.start = start
        self.end = end
        self.samples = samples
        self.confidence = confidence
    }
}

/// Ham ivmeölçer örneklerinden aday içme pencerelerini üreten soyutlama.
/// Faz 2.1'de heuristik; Faz 2.2'de eğitilmiş Core ML modeli bu protokolün
/// arkasına geçer ve üst katman değişmez.
public protocol SmokeDetecting {
    func detect(in samples: [MotionSample]) -> [CandidateWindow]
}

/// Onay bekleyen, diske yazılan aday. Onay (Evet/Hayır) app kapalıyken
/// bildirimle geldiği için aday kalıcı olmalıdır.
public struct PendingCandidate: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let detectedAt: Date
    public let window: CandidateWindow

    public init(id: UUID, detectedAt: Date, window: CandidateWindow) {
        self.id = id
        self.detectedAt = detectedAt
        self.window = window
    }
}
