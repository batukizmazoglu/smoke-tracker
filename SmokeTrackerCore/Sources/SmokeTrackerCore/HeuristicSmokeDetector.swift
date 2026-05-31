import Foundation

/// Heuristik detektörün ayarlanabilir eşikleri. Başlangıç değerleri
/// muhafazakâr/recall-önceliklidir; gerçek değerler cihaz verisiyle kalibre
/// edilecektir (bkz. spec "Dürüstlük notu").
public struct DetectorConfig: Sendable {
    public let spikeThreshold: Double   // ivme büyüklüğü eşiği (yükselen kenar)
    public let maxGap: TimeInterval     // aynı kümede ardışık burst arası max boşluk (s)
    public let minBursts: Int           // aday için min burst sayısı
    public let expectedBursts: Int      // confidence normalizasyonu

    public init(spikeThreshold: Double = 1.5, maxGap: TimeInterval = 90,
                minBursts: Int = 4, expectedBursts: Int = 8) {
        self.spikeThreshold = spikeThreshold
        self.maxGap = maxGap
        self.minBursts = minBursts
        self.expectedBursts = expectedBursts
    }
}

/// `SmokeDetecting`'in saf, deterministik heuristik gerçeklemesi.
public struct HeuristicSmokeDetector: SmokeDetecting {
    private let config: DetectorConfig

    public init(config: DetectorConfig = DetectorConfig()) {
        self.config = config
    }

    public func detect(in samples: [MotionSample]) -> [CandidateWindow] {
        // 1. Yükselen kenar (burst) tespiti.
        var bursts: [MotionSample] = []
        var prevAbove = false
        for s in samples {
            let magnitude = (s.x * s.x + s.y * s.y + s.z * s.z).squareRoot()
            let above = magnitude >= config.spikeThreshold
            if above && !prevAbove { bursts.append(s) }
            prevAbove = above
        }

        // 2. maxGap'e göre kümeleme.
        var clusters: [[MotionSample]] = []
        for b in bursts {
            if let last = clusters.last?.last,
               b.timestamp.timeIntervalSince(last.timestamp) <= config.maxGap {
                clusters[clusters.count - 1].append(b)
            } else {
                clusters.append([b])
            }
        }

        // 3. minBursts filtresi → CandidateWindow.
        return clusters.compactMap { cluster in
            guard cluster.count >= config.minBursts,
                  let first = cluster.first, let last = cluster.last else { return nil }
            let span = samples.filter { $0.timestamp >= first.timestamp && $0.timestamp <= last.timestamp }
            let confidence = min(1.0, Double(cluster.count) / Double(config.expectedBursts))
            return CandidateWindow(start: first.timestamp, end: last.timestamp,
                                   samples: span, confidence: confidence)
        }
    }
}
