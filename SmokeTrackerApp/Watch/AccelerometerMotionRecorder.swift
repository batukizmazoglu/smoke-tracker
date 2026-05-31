import Foundation
import CoreMotion
import SmokeTrackerCore

/// `MotionRecording`'in CMSensorRecorder tabanlı (watchOS) gerçeklemesi.
///
/// CMSensorRecorder arka planda ~50Hz ivmeölçer kaydı yapar ve veriyi sonradan
/// toplu sunar; bu yüzden `stopRecording()` kayıt penceresi için en iyi-çaba
/// (best-effort) senkron bir çekme yapar — kaydın son saniyeleri henüz diske
/// inmemiş olabilir. Bu, MVP eğitim verisi için kabul edilebilir; daha eksiksiz
/// gecikmeli çekme Faz 2 işidir. Sensör verisi YALNIZCA gerçek cihazda akar
/// (simülatörde boş döner).
final class AccelerometerMotionRecorder: MotionRecording {
    private let recorder = CMSensorRecorder()
    private let plannedDuration: TimeInterval
    private var startedAt: Date?

    init(plannedDuration: TimeInterval = 7 * 60) {
        self.plannedDuration = plannedDuration
    }

    /// Motion & Fitness izninin mevcut durumu.
    static var authorizationStatus: CMAuthorizationStatus {
        CMSensorRecorder.authorizationStatus()
    }

    /// İvmeölçer kaydının bu cihazda kullanılabilirliği.
    static var isAvailable: Bool {
        CMSensorRecorder.isAccelerometerRecordingAvailable()
    }

    /// Motion & Fitness iznini proaktif olarak ister. CMSensorRecorder'ın ayrı
    /// bir "izin iste" API'si yoktur; sistem istemi yalnızca recordAccelerometer
    /// ile açılır. Bu yüzden kısa, zararsız (okunmayan) bir kayıt başlatarak
    /// soruyu öne çekeriz; izin reddedilirse kayıt zaten oluşmaz.
    func requestAuthorization() {
        recorder.recordAccelerometer(forDuration: 60)
    }

    func startRecording() {
        startedAt = Date()
        // İlk çağrı, gerekiyorsa Motion & Fitness iznini tetikler.
        recorder.recordAccelerometer(forDuration: plannedDuration)
    }

    func stopRecording() -> [MotionSample] {
        guard let start = startedAt else { return [] }
        startedAt = nil
        guard let list = recorder.accelerometerData(from: start, to: Date()) else { return [] }

        // CMSensorDataList yalnızca NSFastEnumeration'a uyar (Sequence değil),
        // bu yüzden NSFastEnumerationIterator ile gezilir.
        var samples: [MotionSample] = []
        for case let data as CMRecordedAccelerometerData in IteratorSequence(NSFastEnumerationIterator(list)) {
            samples.append(
                MotionSample(
                    timestamp: data.startDate,
                    x: data.acceleration.x,
                    y: data.acceleration.y,
                    z: data.acceleration.z
                )
            )
        }
        return samples
    }
}
