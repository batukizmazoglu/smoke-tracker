# Faz 2.1 — Pasif Aday Tespiti + Onay Döngüsü Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Watch'ta arka planda, ivmeölçer geçmişinden olası içme anlarını aday olarak yakalayıp "Sigara içtin mi?" onayı soran; Evet/Hayır cevaplarından hem +1 sayım hem de dengeli (pozitif + negatif) etiketli eğitim verisi üreten döngüyü kurmak.

**Architecture:** Detektör, değiştirilebilir bir `SmokeDetecting` protokolünün arkasında saf bir heuristiktir (Faz 2.2'de Core ML buraya geçer). Saf çekirdek mantık (detektör, filtre, onay eşlemesi, bildirim bütçesi) `SmokeTrackerCore`/`SmokeTrackerData` paketlerinde TDD ile yazılır ve Mac'te `swift test` ile doğrulanır. Watch'taki arka plan/bildirim glue'su yalnızca gerçek cihazda manuel doğrulanır (derleme + checklist).

**Tech Stack:** Swift 6, Swift Testing (`@Suite`/`@Test`/`#expect`), CoreMotion (`CMSensorRecorder`), UserNotifications, WatchKit arka plan yenileme (`WKApplicationRefreshBackgroundTask`), SwiftUI, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-06-01-smoke-tracker-faz2-tespit-onay-design.md`

---

## Yürütme notları (bu ortamda kritik)

- **Bu Mac simülatör çalıştıramaz.** Paket testleri çalışır; app yalnızca derlenir.
- **Core test:** `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
- **Data test:** `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData`
  (`TMPDIR=/private/tmp` şart — SwiftPM cache sandbox'ı için.)
- **Codex ile koşulursa:** komutu `CLANG_MODULE_CACHE_PATH=/private/tmp/clang-module-cache TMPDIR=/private/tmp swift test --package-path <...> --disable-sandbox` biçiminde, çıktıyı bir dosyaya yönlendirip `</dev/null` ile çalıştır (stdin kilidini önlemek için). Commit'i controller atar.
- **App dosyası ekledikten sonra (Faz B):** önce `xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp`, sonra:
  `xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj`
  (`-sdk` override KULLANMA.) `.xcodeproj` gitignore'da; commit edilmez.
- Paket kaynakları (`Sources/...`) otomatik dahil; Faz A için xcodegen gerekmez.

---

## Dosya yapısı

### Faz A — Çekirdek & veri (saf/test edilebilir, TDD)

| Dosya | Sorumluluk |
|-------|-----------|
| `SmokeTrackerCore/Sources/SmokeTrackerCore/SmokingEvent.swift` (**değişiklik**) | `EventSource`'a `autoConfirmed` |
| `SmokeTrackerCore/Sources/SmokeTrackerCore/SmokeDetection.swift` (**yeni**) | `SmokeDetecting` protokolü, `CandidateWindow`, `PendingCandidate` |
| `SmokeTrackerCore/Sources/SmokeTrackerCore/HeuristicSmokeDetector.swift` (**yeni**) | Saf heuristik detektör + `DetectorConfig` |
| `SmokeTrackerCore/Sources/SmokeTrackerCore/CandidateFilter.swift` (**yeni**) | İmleç/dedup filtresi |
| `SmokeTrackerCore/Sources/SmokeTrackerCore/ConfirmationFlow.swift` (**yeni**) | `ConfirmationResult`, `TrainingLabel`, `outcome` eşlemesi, `PendingCandidateStoring` |
| `SmokeTrackerCore/Sources/SmokeTrackerCore/NotificationBudget.swift` (**yeni**) | `BudgetConfig` + saf bütçe politikası |
| `SmokeTrackerData/Sources/SmokeTrackerData/PendingCandidateStore.swift` (**yeni**) | Pending aday disk deposu |
| `SmokeTrackerData/Sources/SmokeTrackerData/DetectionCursorStore.swift` (**yeni**) | İmleç (UserDefaults) |
| `SmokeTrackerData/Sources/SmokeTrackerData/NotificationBudgetStore.swift` (**yeni**) | Günlük gönderim sayacı (gün sıfırlamalı) |
| `SmokeTrackerData/Sources/SmokeTrackerData/SharedContainer.swift` (**değişiklik**) | `pendingCandidatesURL()` |

### Faz B — Watch/iOS glue (cihazda doğrulanır)

| Dosya | Sorumluluk |
|-------|-----------|
| `SmokeTrackerApp/Watch/SmokeNotificationScheduler.swift` (**yeni**) | Kategori/aksiyon, izin, bütçeli bildirim gönderimi |
| `SmokeTrackerApp/Watch/BackgroundDetectionRunner.swift` (**yeni**) | Arka plan: sensör çek → tespit → pending + bildirim → imleç |
| `SmokeTrackerApp/Watch/NotificationCoordinator.swift` (**yeni**) | `UNUserNotificationCenterDelegate` → onay callback'i |
| `SmokeTrackerApp/Watch/WatchModel.swift` (**değişiklik**) | `confirmCandidate`, bildirim kablajı |
| `SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift` (**değişiklik**) | `.backgroundTask(.appRefresh)` + planlama |
| `SmokeTrackerApp/iOS/TrainingDataView.swift` (**değişiklik**) | Etiket başına (pozitif/negatif) sayı |
| `SmokeTrackerApp/iOS/OnboardingView.swift` (**değişiklik**) | Arka plan tespiti + bildirim sayfası |

---

# FAZ A — Çekirdek & veri (TDD)

## Task 1: `EventSource.autoConfirmed`

**Files:**
- Modify: `SmokeTrackerCore/Sources/SmokeTrackerCore/SmokingEvent.swift:4-7`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SmokingEventTests.swift`

- [ ] **Step 1: Başarısız testi yaz** — `SmokingEventTests.swift` dosyasına ekle:

```swift
@Test func autoConfirmedSourceRoundTrips() throws {
    let event = SmokingEvent(id: UUID(),
                             timestamp: Date(timeIntervalSince1970: 100),
                             source: .autoConfirmed)
    #expect(event.source.rawValue == "autoConfirmed")
    let data = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(SmokingEvent.self, from: data)
    #expect(decoded == event)
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: FAIL — "type 'EventSource' has no member 'autoConfirmed'"

- [ ] **Step 3: Minimal implementasyon** — `EventSource` enum'una case ekle:

```swift
public enum EventSource: String, Codable, Sendable, Equatable {
    case tap            // tek dokunuşla manuel kayıt
    case session        // sensörlü seanstan üretildi
    case autoConfirmed  // arka plan tespitinden onaylandı (Faz 2.1)
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/SmokingEvent.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SmokingEventTests.swift
git commit -m "feat(core): EventSource.autoConfirmed (Faz 2.1)"
```

---

## Task 2: `SmokeDetecting`, `CandidateWindow`, `PendingCandidate`

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/SmokeDetection.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SmokeDetectionTests.swift`

- [ ] **Step 1: Başarısız testi yaz** — `SmokeDetectionTests.swift` (yeni):

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct SmokeDetectionTests {
    @Test func candidateWindowRoundTrips() throws {
        let w = CandidateWindow(
            start: Date(timeIntervalSince1970: 1),
            end: Date(timeIntervalSince1970: 2),
            samples: [MotionSample(timestamp: Date(timeIntervalSince1970: 1), x: 1, y: 2, z: 3)],
            confidence: 0.75
        )
        let data = try JSONEncoder().encode(w)
        #expect(try JSONDecoder().decode(CandidateWindow.self, from: data) == w)
    }

    @Test func pendingCandidateRoundTrips() throws {
        let w = CandidateWindow(
            start: Date(timeIntervalSince1970: 1),
            end: Date(timeIntervalSince1970: 2),
            samples: [],
            confidence: 0.5
        )
        let p = PendingCandidate(id: UUID(), detectedAt: Date(timeIntervalSince1970: 3), window: w)
        let data = try JSONEncoder().encode(p)
        #expect(try JSONDecoder().decode(PendingCandidate.self, from: data) == p)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: FAIL — "cannot find 'CandidateWindow' in scope"

- [ ] **Step 3: Minimal implementasyon** — `SmokeDetection.swift` (yeni):

```swift
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
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/SmokeDetection.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SmokeDetectionTests.swift
git commit -m "feat(core): SmokeDetecting protokolü + CandidateWindow + PendingCandidate"
```

---

## Task 3: `HeuristicSmokeDetector`

Algoritma (saf, deterministik): (1) her örnekte ivme büyüklüğü `m=√(x²+y²+z²)`; `m` eşiği aşağıdan yukarı geçtiğinde bir **burst** (yükselen kenar). (2) Ardışık burst'ler arası boşluk `maxGap`'ten küçükse aynı **kümeye** girer (bir içme seansı = saniyelerle ayrık nefesler). (3) `minBursts`+ burst içeren küme bir `CandidateWindow` olur; `confidence = min(1, burst/expectedBursts)`.

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/HeuristicSmokeDetector.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/HeuristicSmokeDetectorTests.swift`

- [ ] **Step 1: Başarısız testi yaz** — `HeuristicSmokeDetectorTests.swift` (yeni):

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct HeuristicSmokeDetectorTests {
    private func sample(_ t: TimeInterval, burst: Bool) -> MotionSample {
        MotionSample(timestamp: Date(timeIntervalSince1970: t), x: burst ? 2 : 0, y: 0, z: 0)
    }

    /// `count` adet burst üretir; her burst, yükselen kenar için bir "rest"
    /// örneğiyle başlar ve tam saniyede zirve yapar.
    private func bursts(start: TimeInterval, count: Int, step: TimeInterval) -> [MotionSample] {
        var s: [MotionSample] = []
        for i in 0..<count {
            let t = start + Double(i) * step
            s.append(sample(t - 0.5, burst: false))
            s.append(sample(t, burst: true))
        }
        return s
    }

    @Test func flatSignalYieldsNoCandidate() {
        let s = (0..<10).map { sample(Double($0), burst: false) }
        #expect(HeuristicSmokeDetector().detect(in: s).isEmpty)
    }

    @Test func belowMinBurstsYieldsNoCandidate() {
        // 3 burst < minBursts(4)
        #expect(HeuristicSmokeDetector().detect(in: bursts(start: 0, count: 3, step: 2)).isEmpty)
    }

    @Test func clusterOfFourYieldsOneCandidate() {
        let result = HeuristicSmokeDetector().detect(in: bursts(start: 0, count: 4, step: 2))
        #expect(result.count == 1)
        #expect(result.first?.start == Date(timeIntervalSince1970: 0))
        #expect(result.first?.end == Date(timeIntervalSince1970: 6))
        #expect(result.first?.confidence == 0.5)      // 4 / expectedBursts(8)
        #expect(result.first?.samples.isEmpty == false)
    }

    @Test func twoSeparatedClustersYieldTwoCandidates() {
        let s = bursts(start: 0, count: 4, step: 2) + bursts(start: 200, count: 4, step: 2)
        #expect(HeuristicSmokeDetector().detect(in: s).count == 2)
    }

    @Test func isolatedSpikesAreIgnored() {
        let s = [0.0, 200, 400, 600].flatMap { bursts(start: $0, count: 1, step: 1) }
        #expect(HeuristicSmokeDetector().detect(in: s).isEmpty)
    }

    @Test func confidenceCapsAtOne() {
        let result = HeuristicSmokeDetector().detect(in: bursts(start: 0, count: 10, step: 2))
        #expect(result.first?.confidence == 1.0)      // min(1, 10/8)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: FAIL — "cannot find 'HeuristicSmokeDetector' in scope"

- [ ] **Step 3: Minimal implementasyon** — `HeuristicSmokeDetector.swift` (yeni):

```swift
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
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: PASS (6 yeni test)

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/HeuristicSmokeDetector.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/HeuristicSmokeDetectorTests.swift
git commit -m "feat(core): heuristik sigara aday detektörü (recall-öncelikli)"
```

---

## Task 4: `CandidateFilter`

İmleç filtresi: yalnızca `cursor`'dan **sonra** başlayan adayları döndürür; bir önceki tutulan adayla çakışan (start < prevEnd) adayları eler (çakışan batch'lerde tekrar tespiti önler).

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/CandidateFilter.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/CandidateFilterTests.swift`

- [ ] **Step 1: Başarısız testi yaz** — `CandidateFilterTests.swift` (yeni):

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct CandidateFilterTests {
    private func win(_ start: TimeInterval, _ end: TimeInterval) -> CandidateWindow {
        CandidateWindow(start: Date(timeIntervalSince1970: start),
                        end: Date(timeIntervalSince1970: end),
                        samples: [], confidence: 1)
    }

    @Test func dropsCandidatesAtOrBeforeCursor() {
        let r = CandidateFilter.filter([win(10, 20), win(30, 40)],
                                       after: Date(timeIntervalSince1970: 25))
        #expect(r.map(\.start) == [Date(timeIntervalSince1970: 30)])
    }

    @Test func dropsOverlappingCandidate() {
        let r = CandidateFilter.filter([win(10, 50), win(20, 60)],
                                       after: Date(timeIntervalSince1970: 0))
        #expect(r.count == 1)
        #expect(r.first?.start == Date(timeIntervalSince1970: 10))
    }

    @Test func keepsDisjointCandidates() {
        let r = CandidateFilter.filter([win(10, 20), win(30, 40)],
                                       after: Date(timeIntervalSince1970: 0))
        #expect(r.count == 2)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: FAIL — "cannot find 'CandidateFilter' in scope"

- [ ] **Step 3: Minimal implementasyon** — `CandidateFilter.swift` (yeni):

```swift
import Foundation

/// Aday pencerelerini imleç + çakışmaya göre eleyen saf filtre.
public enum CandidateFilter {
    /// Yalnızca `cursor`'dan sonra başlayan, birbiriyle çakışmayan adayları
    /// (başlangıca göre sıralı) döndürür.
    public static func filter(_ candidates: [CandidateWindow], after cursor: Date) -> [CandidateWindow] {
        let sorted = candidates.sorted { $0.start < $1.start }
        var result: [CandidateWindow] = []
        for c in sorted where c.start > cursor {
            if let last = result.last, c.start < last.end { continue }
            result.append(c)
        }
        return result
    }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/CandidateFilter.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/CandidateFilterTests.swift
git commit -m "feat(core): aday imleç/çakışma filtresi"
```

---

## Task 5: `ConfirmationFlow` + `PendingCandidateStoring`

Onay sonucu → ne üretileceği. `smoked` → `autoConfirmed` olay (zaman = pencere başı) + pozitif etiketli `TrainingSession`. `notSmoked` → olay yok + negatif etiketli `TrainingSession`. `PendingCandidateStoring` protokolü de burada (gerçeklemesi Data'da, Task 7).

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/ConfirmationFlow.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/ConfirmationFlowTests.swift`

- [ ] **Step 1: Başarısız testi yaz** — `ConfirmationFlowTests.swift` (yeni):

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct ConfirmationFlowTests {
    private func candidate(start: TimeInterval = 100) -> PendingCandidate {
        let w = CandidateWindow(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: start + 60),
            samples: [MotionSample(timestamp: Date(timeIntervalSince1970: start), x: 1, y: 0, z: 0)],
            confidence: 0.5
        )
        return PendingCandidate(id: UUID(), detectedAt: Date(timeIntervalSince1970: start + 60), window: w)
    }

    @Test func smokedProducesEventAndPositiveTraining() {
        let c = candidate()
        let eventID = UUID(), trainingID = UUID()
        let r = ConfirmationFlow.outcome(for: c, result: .smoked, eventID: eventID, trainingID: trainingID)
        #expect(r.event?.id == eventID)
        #expect(r.event?.source == .autoConfirmed)
        #expect(r.event?.timestamp == c.window.start)
        #expect(r.training.label == TrainingLabel.smoking)
        #expect(r.training.eventID == eventID)
        #expect(r.training.recordedAt == c.window.start)
        #expect(r.training.samples == c.window.samples)
    }

    @Test func notSmokedProducesNegativeTrainingNoEvent() {
        let c = candidate()
        let r = ConfirmationFlow.outcome(for: c, result: .notSmoked, eventID: UUID(), trainingID: UUID())
        #expect(r.event == nil)
        #expect(r.training.label == TrainingLabel.notSmoking)
        #expect(r.training.samples == c.window.samples)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: FAIL — "cannot find 'ConfirmationFlow' in scope"

- [ ] **Step 3: Minimal implementasyon** — `ConfirmationFlow.swift` (yeni):

```swift
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
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/ConfirmationFlow.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/ConfirmationFlowTests.swift
git commit -m "feat(core): onay sonucu → olay/etiket eşlemesi + PendingCandidateStoring"
```

---

## Task 6: `NotificationBudget`

Bildirim yorgunluğuna karşı saf politika: günlük üst sınır + sessiz saatler (gece yarısını saran aralık desteği).

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/NotificationBudget.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/NotificationBudgetTests.swift`

- [ ] **Step 1: Başarısız testi yaz** — `NotificationBudgetTests.swift` (yeni):

```swift
import Testing
@testable import SmokeTrackerCore

@Suite struct NotificationBudgetTests {
    @Test func allowsUnderCapDuringActiveHours() {
        #expect(NotificationBudget.canNotify(sentToday: 0, hour: 12, config: BudgetConfig()) == true)
    }

    @Test func blocksAtDailyCap() {
        #expect(NotificationBudget.canNotify(sentToday: 10, hour: 12, config: BudgetConfig()) == false)
    }

    @Test func blocksDuringQuietHours() {
        #expect(NotificationBudget.canNotify(sentToday: 0, hour: 2, config: BudgetConfig()) == false)
        #expect(NotificationBudget.canNotify(sentToday: 0, hour: 23, config: BudgetConfig()) == false)
    }

    @Test func allowsAtQuietEndBoundary() {
        // quietEndHour(7) hariç → 07:xx artık sessiz değil
        #expect(NotificationBudget.canNotify(sentToday: 0, hour: 7, config: BudgetConfig()) == true)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: FAIL — "cannot find 'NotificationBudget' in scope"

- [ ] **Step 3: Minimal implementasyon** — `NotificationBudget.swift` (yeni):

```swift
import Foundation

/// Bildirim bütçesi ayarları. Başlangıç: günde 10, 23:00–07:00 sessiz.
public struct BudgetConfig: Sendable {
    public let dailyCap: Int
    public let quietStartHour: Int   // dahil
    public let quietEndHour: Int     // hariç

    public init(dailyCap: Int = 10, quietStartHour: Int = 23, quietEndHour: Int = 7) {
        self.dailyCap = dailyCap
        self.quietStartHour = quietStartHour
        self.quietEndHour = quietEndHour
    }
}

/// Onay bildirimi gönderilebilir mi? Saf politika.
public enum NotificationBudget {
    public static func canNotify(sentToday: Int, hour: Int, config: BudgetConfig) -> Bool {
        guard sentToday < config.dailyCap else { return false }
        return !isQuiet(hour: hour, config: config)
    }

    static func isQuiet(hour: Int, config: BudgetConfig) -> Bool {
        if config.quietStartHour <= config.quietEndHour {
            return hour >= config.quietStartHour && hour < config.quietEndHour
        } else {
            // Gece yarısını saran aralık (ör. 23..7).
            return hour >= config.quietStartHour || hour < config.quietEndHour
        }
    }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/NotificationBudget.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/NotificationBudgetTests.swift
git commit -m "feat(core): bildirim bütçesi politikası (günlük sınır + sessiz saat)"
```

---

## Task 7: `PendingCandidateStore` (+ `SharedContainer.pendingCandidatesURL`)

Pending adayların disk deposu. Stateless (her çağrı diskten okur) — arka plan görevi ve onay işleyicisi farklı uyanmalarda çalışabilir. `PendingCandidateStoring` gerçeklemesi.

**Files:**
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/PendingCandidateStore.swift`
- Modify: `SmokeTrackerData/Sources/SmokeTrackerData/SharedContainer.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/PendingCandidateStoreTests.swift`

- [ ] **Step 1: Başarısız testi yaz** — `PendingCandidateStoreTests.swift` (yeni):

```swift
import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct PendingCandidateStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-\(UUID().uuidString).json")
    }

    private func makeCandidate() -> PendingCandidate {
        let w = CandidateWindow(start: Date(timeIntervalSince1970: 1),
                                end: Date(timeIntervalSince1970: 2),
                                samples: [], confidence: 0.5)
        return PendingCandidate(id: UUID(), detectedAt: Date(timeIntervalSince1970: 3), window: w)
    }

    @Test func savedCandidateIsReturned() {
        let store = PendingCandidateStore(url: tempURL())
        let c = makeCandidate()
        store.save(c)
        #expect(store.all() == [c])
    }

    @Test func removeDeletesOnlyGivenCandidate() {
        let store = PendingCandidateStore(url: tempURL())
        let a = makeCandidate(), b = makeCandidate()
        store.save(a); store.save(b)
        store.remove(id: a.id)
        #expect(store.all().map(\.id) == [b.id])
    }

    @Test func saveDeduplicatesById() {
        let store = PendingCandidateStore(url: tempURL())
        let c = makeCandidate()
        store.save(c); store.save(c)
        #expect(store.all().count == 1)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData`
Expected: FAIL — "cannot find 'PendingCandidateStore' in scope"

- [ ] **Step 3a: `SharedContainer.swift`'e konum ekle** — `watchEventsURL`'den sonra:

```swift
    public static func pendingCandidatesURL(appGroup: String = watchAppGroup) -> URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? URL.documentsDirectory
        return base.appendingPathComponent("pending-candidates.json")
    }
```

- [ ] **Step 3b: `PendingCandidateStore.swift` (yeni):**

```swift
import Foundation
import SmokeTrackerCore

/// Onay bekleyen adayları tek bir JSON dosyasında (dizi) saklar. Stateless:
/// her çağrı diski yeniden okur; böylece arka plan görevi ve onay işleyicisi
/// ayrı uyanmalarda tutarlı çalışır. Best-effort (yazma hatasını yutmaz ama
/// fırlatmaz).
///
/// NOT: Tek bir aktörden (uygulamada MainActor) kullanılmalıdır.
public final class PendingCandidateStore: PendingCandidateStoring {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func save(_ candidate: PendingCandidate) {
        var all = load()
        all.removeAll { $0.id == candidate.id }
        all.append(candidate)
        persist(all)
    }

    public func all() -> [PendingCandidate] {
        load()
    }

    public func remove(id: UUID) {
        var all = load()
        all.removeAll { $0.id == id }
        persist(all)
    }

    private func load() -> [PendingCandidate] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([PendingCandidate].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persist(_ items: [PendingCandidate]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("[PendingCandidateStore] persist başarısız: \(error)")
            #endif
        }
    }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerData/Sources/SmokeTrackerData/PendingCandidateStore.swift SmokeTrackerData/Sources/SmokeTrackerData/SharedContainer.swift SmokeTrackerData/Tests/SmokeTrackerDataTests/PendingCandidateStoreTests.swift
git commit -m "feat(data): pending aday disk deposu + SharedContainer konumu"
```

---

## Task 8: `DetectionCursorStore`

Son işlenen imleç zamanı (UserDefaults). Hiç yazılmadıysa `nil`.

**Files:**
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/DetectionCursorStore.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/DetectionCursorStoreTests.swift`

- [ ] **Step 1: Başarısız testi yaz** — `DetectionCursorStoreTests.swift` (yeni):

```swift
import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct DetectionCursorStoreTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "cursor-\(UUID().uuidString)")!
    }

    @Test func cursorDefaultsToNil() {
        #expect(DetectionCursorStore(defaults: defaults()).cursor == nil)
    }

    @Test func cursorPersists() {
        let store = DetectionCursorStore(defaults: defaults())
        let d = Date(timeIntervalSince1970: 12345)
        store.cursor = d
        #expect(store.cursor == d)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData`
Expected: FAIL — "cannot find 'DetectionCursorStore' in scope"

- [ ] **Step 3: Minimal implementasyon** — `DetectionCursorStore.swift` (yeni):

```swift
import Foundation

/// Arka plan tespitinin son işlediği zamanı (imleç) UserDefaults'ta saklar.
public final class DetectionCursorStore {
    private let defaults: UserDefaults
    private let key = "detection_cursor"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var cursor: Date? {
        get {
            let t = defaults.double(forKey: key)   // anahtar yoksa 0
            return t == 0 ? nil : Date(timeIntervalSince1970: t)
        }
        set {
            defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: key)
        }
    }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerData/Sources/SmokeTrackerData/DetectionCursorStore.swift SmokeTrackerData/Tests/SmokeTrackerDataTests/DetectionCursorStoreTests.swift
git commit -m "feat(data): arka plan tespit imleci deposu"
```

---

## Task 9: `NotificationBudgetStore`

Bugün gönderilen bildirim sayısını tutar; gün değişince sıfırlanır. Test için `DateProviding` enjekte edilir.

**Files:**
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/NotificationBudgetStore.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/NotificationBudgetStoreTests.swift`

- [ ] **Step 1: Başarısız testi yaz** — `NotificationBudgetStoreTests.swift` (yeni):

```swift
import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct NotificationBudgetStoreTests {
    private final class StubDate: DateProviding {
        var value: Date
        init(_ value: Date) { self.value = value }
        func now() -> Date { value }
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "budget-\(UUID().uuidString)")!
    }

    @Test func sentTodayStartsAtZero() {
        let store = NotificationBudgetStore(defaults: defaults(),
                                            dateProvider: StubDate(Date(timeIntervalSince1970: 0)))
        #expect(store.sentToday() == 0)
    }

    @Test func recordSentIncrements() {
        let store = NotificationBudgetStore(defaults: defaults(),
                                            dateProvider: StubDate(Date(timeIntervalSince1970: 0)))
        store.recordSent()
        store.recordSent()
        #expect(store.sentToday() == 2)
    }

    @Test func countResetsOnNewDay() {
        let date = StubDate(Date(timeIntervalSince1970: 0))
        let store = NotificationBudgetStore(defaults: defaults(), dateProvider: date)
        store.recordSent()
        date.value = Date(timeIntervalSince1970: 0).addingTimeInterval(48 * 3600)
        #expect(store.sentToday() == 0)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData`
Expected: FAIL — "cannot find 'NotificationBudgetStore' in scope"

- [ ] **Step 3: Minimal implementasyon** — `NotificationBudgetStore.swift` (yeni):

```swift
import Foundation
import SmokeTrackerCore

/// Bugün gönderilen onay bildirimi sayısını tutar; takvim günü değişince
/// otomatik sıfırlanır. Gün anahtarı yerel takvime göre hesaplanır.
public final class NotificationBudgetStore {
    private let defaults: UserDefaults
    private let dateProvider: DateProviding
    private let countKey = "notif_sent_count"
    private let dayKey = "notif_sent_day"

    public init(defaults: UserDefaults = .standard, dateProvider: DateProviding = SystemDateProvider()) {
        self.defaults = defaults
        self.dateProvider = dateProvider
    }

    public func sentToday() -> Int {
        guard defaults.string(forKey: dayKey) == currentDayKey() else { return 0 }
        return defaults.integer(forKey: countKey)
    }

    public func recordSent() {
        let today = currentDayKey()
        if defaults.string(forKey: dayKey) != today {
            defaults.set(today, forKey: dayKey)
            defaults.set(0, forKey: countKey)
        }
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
    }

    private func currentDayKey() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: dateProvider.now())
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerData/Sources/SmokeTrackerData/NotificationBudgetStore.swift SmokeTrackerData/Tests/SmokeTrackerDataTests/NotificationBudgetStoreTests.swift
git commit -m "feat(data): günlük bildirim sayacı (gün sıfırlamalı)"
```

---

# FAZ B — Watch/iOS glue (cihazda doğrulanır)

> Bu fazda ünite testi yoktur (sensör/arka plan/bildirim yalnızca gerçek cihazda akar). Her task: **derleme başarısı** + **manuel cihaz checklist'i**. Her app dosyası eklemeden sonra `xcodegen generate` çalıştır.

## Task 10: `SmokeNotificationScheduler`

**Files:**
- Create: `SmokeTrackerApp/Watch/SmokeNotificationScheduler.swift`

> Not: watchOS'ta onay bildirimi için Info.plist anahtarı gerekmez (izin runtime'da istenir; `WKApplicationRefreshBackgroundTask` özel entitlement istemez). Mevcut `NSMotionUsageDescription` korunur.

- [ ] **Step 1: `SmokeNotificationScheduler.swift` (yeni):**

```swift
import Foundation
import UserNotifications
import SmokeTrackerCore
import SmokeTrackerData

/// "Sigara içtin mi?" onay bildirimini kurar ve (bütçe izniyle) gönderir.
@MainActor
enum SmokeNotificationScheduler {
    static let categoryID = "SMOKE_CONFIRM"
    static let yesAction = "SMOKE_YES"
    static let noAction = "SMOKE_NO"
    static let candidateKey = "candidateID"

    /// Evet/Hayır aksiyonlu kategoriyi kaydeder (açılışta bir kez).
    static func registerCategory() {
        let yes = UNNotificationAction(identifier: yesAction, title: "Evet", options: [])
        let no = UNNotificationAction(identifier: noAction, title: "Hayır", options: [])
        let category = UNNotificationCategory(identifier: categoryID, actions: [yes, no],
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Bildirim iznini ister; reddedilirse özellik sessizce devre dışı kalır.
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Bütçe izin veriyorsa aday için onay bildirimi planlar; gönderirse true.
    @discardableResult
    static func notifyIfAllowed(for candidate: PendingCandidate,
                               budgetStore: NotificationBudgetStore,
                               config: BudgetConfig = BudgetConfig()) -> Bool {
        let hour = Calendar.current.component(.hour, from: candidate.detectedAt)
        guard NotificationBudget.canNotify(sentToday: budgetStore.sentToday(),
                                           hour: hour, config: config) else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Sigara içtin mi?"
        let time = candidate.window.start.formatted(date: .omitted, time: .shortened)
        content.body = "~\(time) civarında bir hareket fark ettik."
        content.categoryIdentifier = categoryID
        content.userInfo = [candidateKey: candidate.id.uuidString]

        let request = UNNotificationRequest(identifier: candidate.id.uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        budgetStore.recordSent()
        return true
    }
}
```

- [ ] **Step 2: Üret + derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add SmokeTrackerApp/Watch/SmokeNotificationScheduler.swift
git commit -m "feat(watch): onay bildirimi planlayıcı (kategori + bütçe kapısı)"
```

---

## Task 11: `BackgroundDetectionRunner` + arka plan yenileme kablajı

**Files:**
- Create: `SmokeTrackerApp/Watch/BackgroundDetectionRunner.swift`
- Modify: `SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift`

- [ ] **Step 1: `BackgroundDetectionRunner.swift` (yeni):**

```swift
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
```

- [ ] **Step 2: `SmokeTrackerWatchApp.swift`'i güncelle** — arka plan görevini ve planlamayı ekle. Tam dosya:

```swift
import SwiftUI
import WatchKit

@main
struct SmokeTrackerWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    static let refreshID = "com.oero.smoketracker.detect"

    var body: some Scene {
        WindowGroup {
            WatchTodayView(model: model)
                .onOpenURL { url in
                    if url.scheme == "smoketracker", url.host(percentEncoded: false) == "log" {
                        model.logFromComplication()
                    }
                }
        }
        .backgroundTask(.appRefresh(Self.refreshID)) {
            await MainActor.run { BackgroundDetectionRunner().run() }
            await MainActor.run { Self.scheduleNextRefresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
                Self.scheduleNextRefresh()
            }
        }
    }

    /// Bir sonraki arka plan yenilemesini planlar (~20 dk sonra; sistem kısıtlar).
    static func scheduleNextRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(20 * 60),
            userInfo: nil
        ) { _ in }
    }
}
```

- [ ] **Step 3: Üret + derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```
Expected: BUILD SUCCEEDED

> **Cihaz doğrulama notu:** `.backgroundTask(.appRefresh:)` + `scheduleBackgroundRefresh` kablajı yalnızca gerçek cihazda doğrulanır; sistem yenileme sıklığını kısar (dakikalar–saatler). İlk yenileme, app bir kez açılıp `scheduleNextRefresh` çağrıldıktan sonra planlanır.

- [ ] **Step 4: Commit**

```bash
git add SmokeTrackerApp/Watch/BackgroundDetectionRunner.swift SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift
git commit -m "feat(watch): arka plan tespit koşucusu + appRefresh planlama"
```

---

## Task 12: `WatchModel.confirmCandidate` + `NotificationCoordinator`

**Files:**
- Create: `SmokeTrackerApp/Watch/NotificationCoordinator.swift`
- Modify: `SmokeTrackerApp/Watch/WatchModel.swift`

- [ ] **Step 1: `NotificationCoordinator.swift` (yeni):**

```swift
import Foundation
import UserNotifications
import SmokeTrackerCore

/// Bildirim aksiyonlarını (Evet/Hayır) WatchModel'e ileten tek
/// UNUserNotificationCenter delegate'i. (WCSession delegate'i ayrı —
/// WatchSyncSender; çakışma yok.)
@MainActor
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    var onConfirm: ((UUID, ConfirmationResult) -> Void)?

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let idString = info[SmokeNotificationScheduler.candidateKey] as? String
        let action = response.actionIdentifier
        Task { @MainActor in
            if let idString, let id = UUID(uuidString: idString) {
                switch action {
                case SmokeNotificationScheduler.yesAction: self.onConfirm?(id, .smoked)
                case SmokeNotificationScheduler.noAction: self.onConfirm?(id, .notSmoked)
                default: break   // gövdeye dokunma / kapatma → işlem yok
                }
            }
            completionHandler()
        }
    }

    /// Uygulama ön plandayken de bildirimi göster.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

- [ ] **Step 2: `WatchModel.swift`'i güncelle** — `import UserNotifications` ekle; yeni alanlar + init kablajı + `confirmCandidate`.

Dosya başına ekle:
```swift
import UserNotifications
```

Alanlara ekle (mevcut `private let complicationThrottle...` satırından sonra):
```swift
    private let pendingStore = PendingCandidateStore(url: SharedContainer.pendingCandidatesURL())
    private let notificationCoordinator = NotificationCoordinator()
```

`init()` içinde, mevcut `self.sender.activate()` satırından **sonra** ekle:
```swift
        // Bildirim onay kablajı.
        SmokeNotificationScheduler.registerCategory()
        SmokeNotificationScheduler.requestAuthorization()
        notificationCoordinator.onConfirm = { [weak self] id, result in
            self?.confirmCandidate(id: id, result: result)
        }
        UNUserNotificationCenter.current().delegate = notificationCoordinator
```

`refresh()` metodundan **önce** yeni metot ekle:
```swift
    /// Bildirim onayını işler: Evet → +1 olay (autoConfirmed) + pozitif eğitim
    /// verisi; Hayır → yalnızca negatif eğitim verisi. Her ikisi de izinle.
    func confirmCandidate(id: UUID, result: ConfirmationResult) {
        guard let candidate = pendingStore.all().first(where: { $0.id == id }) else { return }
        let outcome = ConfirmationFlow.outcome(for: candidate, result: result,
                                               eventID: UUID(), trainingID: UUID())
        if let event = outcome.event {
            store.add(event)
            sender.send(event)
        }
        if trainingDataConsent {
            sender.sendTrainingSession(outcome.training)
        }
        pendingStore.remove(id: id)
        refresh()
        WidgetCenter.shared.reloadAllTimelines()
    }
```

- [ ] **Step 3: Üret + derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add SmokeTrackerApp/Watch/NotificationCoordinator.swift SmokeTrackerApp/Watch/WatchModel.swift
git commit -m "feat(watch): onay işleme (Evet→+1/pozitif, Hayır→negatif) + bildirim delegate'i"
```

---

## Task 13: iOS — etiket sayıları + onboarding sayfası

**Files:**
- Modify: `SmokeTrackerApp/iOS/TrainingDataView.swift`
- Modify: `SmokeTrackerApp/iOS/OnboardingView.swift`

- [ ] **Step 1: `TrainingDataView.swift`** — "Kayıtlı seanslar" Section başlığından önce, pozitif/negatif sayım Section'ı ekle. Mevcut ilk `Section { Toggle... }` bloğundan sonra ekle:

```swift
            Section("Toplanan veri") {
                let positive = model.trainingSessions.filter { $0.label == TrainingLabel.smoking }.count
                let negative = model.trainingSessions.filter { $0.label == TrainingLabel.notSmoking }.count
                LabeledContent("Sigara (pozitif)", value: "\(positive)")
                LabeledContent("Sigara değil (negatif)", value: "\(negative)")
                Text("Dengeli pozitif + negatif örnek, ileride otomatik tanıma modelini eğitmek için gerekli.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
```

- [ ] **Step 2: `OnboardingView.swift`** — arka plan tespiti sayfası ekle. `howItWorks` ile `privacy` arasına yeni sayfa; `TabView` içindeki tag'leri güncelle.

`TabView` gövdesini şu hâle getir:
```swift
        TabView(selection: $page) {
            welcome.tag(0)
            howItWorks.tag(1)
            autoDetect.tag(2)
            privacy.tag(3)
        }
```

`howItWorks` hesaplanan özelliğinden sonra yeni özellik ekle:
```swift
    private var autoDetect: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Otomatik tespit")
                .font(.title.bold())
            Label("Saatin, arka planda olası içme anlarını fark edip \"Sigara içtin mi?\" diye sorabilir.", systemImage: "bell.badge")
            Label("Cevabın asla otomatik saymaz — yalnızca \"Evet\" dersen +1 işlenir.", systemImage: "checkmark.seal")
            Label("Bunun için saatte bildirim iznini vermen gerekir; reddedersen +1 ve seans çalışmaya devam eder.", systemImage: "hand.raised")
            Spacer()
            nextHint
        }
        .padding(32)
    }
```

- [ ] **Step 3: Üret + derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add SmokeTrackerApp/iOS/TrainingDataView.swift SmokeTrackerApp/iOS/OnboardingView.swift
git commit -m "feat(ios): eğitim verisi pozitif/negatif sayımı + onboarding tespit sayfası"
```

---

## Cihaz manuel test checklist'i (Faz B, gerçek cihaz gerektirir)

> Bu Mac simülatör çalıştıramadığı için yalnızca gerçek iPhone + Watch'ta doğrulanır. İmzalama hazır olunca yürüt.

- [ ] Onboarding'de "Otomatik tespit" sayfası görünüyor; bildirim izni isteniyor.
- [ ] Saatte bir içme hareketi taklit et (kol-ağız tekrarları) → arka plan yenilemeden sonra "Sigara içtin mi?" bildirimi geliyor.
- [ ] Bildirimde **Evet** → bugünkü sayı +1; iPhone'a `autoConfirmed` olay senkronu; izin açıksa pozitif eğitim seansı iPhone arşivinde.
- [ ] Bildirimde **Hayır** → sayı değişmiyor; izin açıksa **negatif** ("sigara_degil") seans iPhone arşivinde.
- [ ] Aynı pencere için ikinci bir bildirim gelmiyor (imleç/dedup çalışıyor).
- [ ] Günlük üst sınır aşılınca / sessiz saatte bildirim gelmiyor.
- [ ] Bildirim izni reddedilince: +1, complication ve seans hâlâ çalışıyor.
- [ ] iPhone "Eğitim verisi" ekranında pozitif/negatif sayıları doğru.

---

## Kapanış notları

- **Beklenen test sayıları:** Core `swift test` ~+18 test (mevcut 29 → ~47), Data ~+8 test (mevcut 27 → ~35). (Faz B'de ünite testi yok.)
- **YAGNI:** Eğitilmiş ML modeli, CreateML hattı, canlı/gerçek-zamanlı tespit — Faz 2.2'ye bırakıldı. Bu plan yalnızca heuristik döngüyü ve veri köprüsünü kurar.
- **Dürüstlük:** Faz B'deki arka plan yenileme tetiği, gerçek sensör verisi, bildirim teslimi ve izin diyalogları yalnızca gerçek cihazda doğrulanabilir; bu planda derleme başarısı + manuel checklist ile kapsanır. Heuristik eşikler cihaz verisiyle kalibre edilecek (ilk değerler muhafazakâr).
- **Bağımlılık:** Faz B'nin gerçek değeri ancak cihazda doğrulanır; bu da Faz 1'in cihaza kurulmasını (imzalama) gerektirir. Faz A tamamen bu Mac'te doğrulanabilir.
