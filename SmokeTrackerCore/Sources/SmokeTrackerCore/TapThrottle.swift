import Foundation

/// Aynı eylemin çok kısa aralıkla tekrarını engelleyen basit kısıtlayıcı.
/// Complication'dan gelen +1 dokunuşlarının (URL'in iki kez teslimi, kazara
/// çift dokunuş) tekrar sayılmasını önlemek için kullanılır.
public final class TapThrottle {
    private let minInterval: TimeInterval
    private var lastAcceptedAt: Date?

    public init(minInterval: TimeInterval) {
        self.minInterval = minInterval
    }

    /// Verilen ana göre eylemi kabul eder mi? Kabul ederse son-kabul zamanını
    /// günceller ve `true`, aksi halde `false` döner.
    public func accept(at now: Date) -> Bool {
        if let last = lastAcceptedAt, now.timeIntervalSince(last) < minInterval {
            return false
        }
        lastAcceptedAt = now
        return true
    }
}
