import Foundation

/// Tek bir ivmeölçer örneği (Faz 2 eğitim verisi için).
public struct MotionSample: Equatable, Codable, Sendable {
    public let timestamp: Date
    public let x: Double
    public let y: Double
    public let z: Double

    public init(timestamp: Date, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }
}

/// Hareket kaydı soyutlaması. Plan 3'te CMSensorRecorder ile gerçeklenecek.
public protocol MotionRecording {
    func startRecording()
    func stopRecording() -> [MotionSample]
}
