import Foundation

/// Seansın durumu.
public enum SessionState: Equatable, Sendable {
    case idle
    case recording
    case finished
}

/// Bir seansın sonucu: üretilen olay + kaydedilen ham örnekler.
public struct SessionResult: Equatable, Sendable {
    public let event: SmokingEvent
    public let samples: [MotionSample]

    public init(event: SmokingEvent, samples: [MotionSample]) {
        self.event = event
        self.samples = samples
    }
}

/// Opsiyonel sensörlü seansın durum makinesi.
/// start() kaydı başlatır; stop() kaydı bitirip bir .session olayı üretir.
public final class SessionRecorder {
    public private(set) var state: SessionState = .idle

    private let motion: MotionRecording
    private let dateProvider: DateProviding
    private let idProvider: () -> UUID

    public init(
        motion: MotionRecording,
        dateProvider: DateProviding,
        idProvider: @escaping () -> UUID = { UUID() }
    ) {
        self.motion = motion
        self.dateProvider = dateProvider
        self.idProvider = idProvider
    }

    /// Seansı başlatır (idle veya bitmiş bir seansın ardından).
    /// Hâlihazırda kayıttaysa hiçbir şey yapmaz; böylece aynı örnek
    /// gün içinde birden çok seans için yeniden kullanılabilir.
    public func start() {
        guard state != .recording else { return }
        motion.startRecording()
        state = .recording
    }

    /// Seansı bitirir; kayıttaysa SessionResult döndürür, değilse nil.
    @discardableResult
    public func stop() -> SessionResult? {
        guard state == .recording else { return nil }
        let samples = motion.stopRecording()
        let event = SmokingEvent(
            id: idProvider(),
            timestamp: dateProvider.now(),
            source: .session
        )
        state = .finished
        return SessionResult(event: event, samples: samples)
    }
}
