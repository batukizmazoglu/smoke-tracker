# Sensörlü Seans + Eğitim Verisi Arşivi Uygulama Planı (Plan 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apple Watch'ta opsiyonel sensörlü seansı uçtan uca çalışır hale getir — `SessionRecorder`'ı gerçek `CMSensorRecorder` ile bağla, seans bitince +1 işle ve ham hareket verisini (kullanıcı izniyle) iPhone'daki kalıcı eğitim arşivine taşı. Bu, Faz 2 otomatik tespiti için etiketli veri köprüsünü kurar.

**Architecture:** Test edilebilir öz (TrainingSession modeli, dosya tabanlı arşiv, kodlayıcı, izin deposu) SPM paketlerine (`SmokeTrackerCore` + `SmokeTrackerData`) TDD ile yazılır ve `swift test` ile doğrulanır. Donanıma bağımlı parçalar (CMSensorRecorder adaptörü, seans UI'ı, dosya senkronu) app hedeflerine yazılır ve yalnızca **derleme** ile doğrulanır (bu ortamda simülatör/cihaz çalıştırılamıyor — bkz. Ortam Notu). WCSession'da tek delegate kuralı korunur: watch'ta gönderim mevcut `WatchSyncSender`'a, iPhone'da alım mevcut `PhoneSyncReceiver`'a eklenir; yeni delegate sınıfı yaratılmaz.

**Tech Stack:** Swift 6 (language mode), SwiftUI (watchOS + iOS), CoreMotion (`CMSensorRecorder`), WatchConnectivity (`transferUserInfo` + `transferFile`), SwiftData (mevcut), Foundation (`FileManager`, `UserDefaults`, `Codable`), Swift Testing (`@Suite`/`@Test`/`#expect`), XcodeGen.

---

## Ortam Notu (kritik — her app-derleme adımında geçerli)

Bu Mac'te simülatör/cihaz çalıştırılamıyor (CoreSimulator sürüm uyumsuzluğu + yalnızca 26.4 runtime'ları kurulu). Dolayısıyla:

- Paket katmanı tam test edilir: `swift test --package-path SmokeTrackerCore` ve `swift test --package-path SmokeTrackerData`.
- App katmanı **yalnızca derlenerek** doğrulanır. Yeni app dosyası ekledikten sonra önce projeyi yeniden üret, sonra derle:

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker \
  -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```

`-sdk` override'ı **KULLANMA** (gömülü watch app'i yanlış SDK'ya zorlar). `SmokeTracker` hedefini derlemek gömülü `SmokeTrackerWatch` hedefini de kendi watchOS SDK'sıyla derler. Beklenen sonuç: `** BUILD SUCCEEDED **`. CMSensorRecorder sensör verisi yalnızca gerçek cihazda akar; bu yüzden seansın uçtan uca davranış doğrulaması kullanıcının ortamı düzelince yapılacak.

`SmokeTrackerApp/project.yml` Plan 3 için **değişmez**: yeni app kaynakları `sources: - path: Watch` / `- path: iOS` glob'larıyla otomatik dahil olur; complication için widget extension hedefi Plan 4'e bırakıldı.

---

## Kapsam (Plan 3) ve kapsam dışı (Plan 4)

**Plan 3 (bu plan):** Sensörlü seans kaydı (CMSensorRecorder), seans → +1, ham veri → iPhone eğitim arşivi (izinle), minimal izin/onay (seans ekranında varsayılan-kapalı toggle + iPhone'da eğitim verisi yönetim ekranı), gün sınırı için öne-gelince yenileme.

**Plan 4 (sonraki):** Complication (kadrandan tek dokunuş, birincil giriş), tam onboarding akışı, ayrı gizlilik/izin ekranı ve Motion & Fitness izninin proaktif istenmesi. Plan 3'teki seans-içi toggle, Plan 4'te onboarding-temelli onayla değiştirilecek/zenginleştirilecek.

---

## File Structure

**Yeni — test edilebilir paket katmanı:**
- `SmokeTrackerCore/Sources/SmokeTrackerCore/TrainingData.swift` — `TrainingSession` modeli + `TrainingDataArchiving` protokolü.
- `SmokeTrackerCore/Sources/SmokeTrackerCore/Consent.swift` — `ConsentProviding` protokolü.
- `SmokeTrackerData/Sources/SmokeTrackerData/FileTrainingDataArchive.swift` — dizin tabanlı arşiv (seans başına 1 JSON).
- `SmokeTrackerData/Sources/SmokeTrackerData/TrainingSessionCodec.swift` — `TrainingSession` ⇄ `Data` (dosya transferi).
- `SmokeTrackerData/Sources/SmokeTrackerData/UserDefaultsConsentStore.swift` — `ConsentProviding`'in UserDefaults gerçeklemesi.
- Testler: `SmokeTrackerCoreTests/TrainingDataTests.swift`, `SmokeTrackerDataTests/FileTrainingDataArchiveTests.swift`, `SmokeTrackerDataTests/TrainingSessionCodecTests.swift`, `SmokeTrackerDataTests/UserDefaultsConsentStoreTests.swift`.

**Yeni — app katmanı (derleme ile doğrulanır):**
- `SmokeTrackerApp/Watch/AccelerometerMotionRecorder.swift` — `MotionRecording`'in CMSensorRecorder gerçeklemesi.
- `SmokeTrackerApp/Watch/WatchSessionView.swift` — seans başlat/bitir ekranı.
- `SmokeTrackerApp/iOS/TrainingDataView.swift` — eğitim verisi onay + yönetim (listele/sil) ekranı.

**Değişen — app katmanı:**
- `SmokeTrackerApp/Watch/Info.plist` — `NSMotionUsageDescription`.
- `SmokeTrackerApp/Watch/WatchModel.swift` — seans durumu + start/stop + izin.
- `SmokeTrackerApp/Watch/WatchSyncSender.swift` — `sendTrainingSession(_:)` (`transferFile`).
- `SmokeTrackerApp/Watch/WatchTodayView.swift` — Seans ekranına NavigationLink.
- `SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift` — scenePhase → refresh.
- `SmokeTrackerApp/iOS/PhoneSyncReceiver.swift` — `didReceive file` → arşiv.
- `SmokeTrackerApp/iOS/PhoneModel.swift` — arşiv + izin + seansları açığa çıkar.
- `SmokeTrackerApp/iOS/TodayView.swift` — Eğitim verisi ekranına NavigationLink.
- `SmokeTrackerApp/iOS/SmokeTrackerApp.swift` — scenePhase → refresh.

---

## Task 1: TrainingSession modeli + TrainingDataArchiving protokolü (Core)

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/TrainingData.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/TrainingDataTests.swift`

- [ ] **Step 1: Failing test yaz**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/TrainingDataTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct TrainingDataTests {
    @Test func trainingSessionRoundTripsThroughCodable() throws {
        let sample = MotionSample(
            timestamp: Date(timeIntervalSince1970: 100),
            x: 0.1, y: -0.2, z: 9.8
        )
        let session = TrainingSession(
            id: UUID(),
            eventID: UUID(),
            recordedAt: Date(timeIntervalSince1970: 200),
            label: "sigara",
            samples: [sample]
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(TrainingSession.self, from: data)

        #expect(decoded == session)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter TrainingDataTests`
Expected: FAIL — `cannot find 'TrainingSession' in scope` (derleme hatası).

- [ ] **Step 3: Minimal implementasyon yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/TrainingData.swift`:

```swift
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
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter TrainingDataTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/TrainingData.swift \
        SmokeTrackerCore/Tests/SmokeTrackerCoreTests/TrainingDataTests.swift
git commit -m "feat(core): TrainingSession modeli + TrainingDataArchiving protokolü"
```

---

## Task 2: FileTrainingDataArchive (Data)

**Files:**
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/FileTrainingDataArchive.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/FileTrainingDataArchiveTests.swift`

- [ ] **Step 1: Failing test yaz**

`SmokeTrackerData/Tests/SmokeTrackerDataTests/FileTrainingDataArchiveTests.swift`:

```swift
import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct FileTrainingDataArchiveTests {
    private func makeTempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("training-test-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeSession(recordedAt: TimeInterval = 1000) -> TrainingSession {
        TrainingSession(
            id: UUID(),
            eventID: UUID(),
            recordedAt: Date(timeIntervalSince1970: recordedAt),
            label: "sigara",
            samples: [MotionSample(timestamp: Date(timeIntervalSince1970: recordedAt), x: 1, y: 2, z: 3)]
        )
    }

    @Test func savedSessionIsReturnedByAllSessions() throws {
        let archive = FileTrainingDataArchive(directory: makeTempDir())
        let session = makeSession()
        try archive.save(session)
        #expect(archive.allSessions() == [session])
    }

    @Test func deleteRemovesOnlyTheGivenSession() throws {
        let archive = FileTrainingDataArchive(directory: makeTempDir())
        let a = makeSession(recordedAt: 100)
        let b = makeSession(recordedAt: 200)
        try archive.save(a)
        try archive.save(b)
        try archive.delete(id: a.id)
        #expect(archive.allSessions() == [b])
    }

    @Test func deleteAllEmptiesArchive() throws {
        let archive = FileTrainingDataArchive(directory: makeTempDir())
        try archive.save(makeSession())
        try archive.save(makeSession())
        try archive.deleteAll()
        #expect(archive.allSessions().isEmpty)
    }

    @Test func allSessionsAreSortedByRecordedAt() throws {
        let archive = FileTrainingDataArchive(directory: makeTempDir())
        let older = makeSession(recordedAt: 100)
        let newer = makeSession(recordedAt: 200)
        try archive.save(newer)
        try archive.save(older)
        #expect(archive.allSessions().map(\.id) == [older.id, newer.id])
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerData --filter FileTrainingDataArchiveTests`
Expected: FAIL — `cannot find 'FileTrainingDataArchive' in scope`.

- [ ] **Step 3: Minimal implementasyon yaz**

`SmokeTrackerData/Sources/SmokeTrackerData/FileTrainingDataArchive.swift`:

```swift
import Foundation
import SmokeTrackerCore

/// Eğitim seanslarını disk üzerinde bir dizinde, seans başına bir JSON dosyası
/// (`<id>.json`) olarak saklar. iPhone tarafında, kullanıcı izniyle kullanılır.
///
/// NOT: Tek bir iş parçacığından/aktörden (uygulamada MainActor) kullanılmalıdır.
public final class FileTrainingDataArchive: TrainingDataArchiving {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save(_ session: TrainingSession) throws {
        let url = directory.appendingPathComponent("\(session.id.uuidString).json")
        let data = try JSONEncoder().encode(session)
        try data.write(to: url, options: .atomic)
    }

    public func allSessions() -> [TrainingSession] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> TrainingSession? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(TrainingSession.self, from: data)
            }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    public func delete(id: UUID) throws {
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    public func deleteAll() throws {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in urls where url.pathExtension == "json" {
            try fileManager.removeItem(at: url)
        }
    }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerData --filter FileTrainingDataArchiveTests`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerData/Sources/SmokeTrackerData/FileTrainingDataArchive.swift \
        SmokeTrackerData/Tests/SmokeTrackerDataTests/FileTrainingDataArchiveTests.swift
git commit -m "feat(data): FileTrainingDataArchive (dizin tabanlı eğitim verisi arşivi)"
```

---

## Task 3: TrainingSessionCodec (Data)

**Files:**
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/TrainingSessionCodec.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/TrainingSessionCodecTests.swift`

- [ ] **Step 1: Failing test yaz**

`SmokeTrackerData/Tests/SmokeTrackerDataTests/TrainingSessionCodecTests.swift`:

```swift
import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct TrainingSessionCodecTests {
    @Test func encodeDecodeRoundTripPreservesSession() throws {
        let session = TrainingSession(
            id: UUID(),
            eventID: UUID(),
            recordedAt: Date(timeIntervalSince1970: 500),
            label: "sigara",
            samples: [
                MotionSample(timestamp: Date(timeIntervalSince1970: 500), x: 0.1, y: 0.2, z: 0.3),
                MotionSample(timestamp: Date(timeIntervalSince1970: 501), x: 1, y: 2, z: 3)
            ]
        )

        let data = try TrainingSessionCodec.encode(session)
        let decoded = try TrainingSessionCodec.decode(data)

        #expect(decoded == session)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerData --filter TrainingSessionCodecTests`
Expected: FAIL — `cannot find 'TrainingSessionCodec' in scope`.

- [ ] **Step 3: Minimal implementasyon yaz**

`SmokeTrackerData/Sources/SmokeTrackerData/TrainingSessionCodec.swift`:

```swift
import Foundation
import SmokeTrackerCore

/// `TrainingSession`'ı WCSession dosya transferi için kodlar/çözer.
/// (Ham veri büyük olabildiğinden `transferUserInfo` yerine dosya kullanılır.)
public enum TrainingSessionCodec {
    public static func encode(_ session: TrainingSession) throws -> Data {
        try JSONEncoder().encode(session)
    }

    public static func decode(_ data: Data) throws -> TrainingSession {
        try JSONDecoder().decode(TrainingSession.self, from: data)
    }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerData --filter TrainingSessionCodecTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerData/Sources/SmokeTrackerData/TrainingSessionCodec.swift \
        SmokeTrackerData/Tests/SmokeTrackerDataTests/TrainingSessionCodecTests.swift
git commit -m "feat(data): TrainingSessionCodec (eğitim verisi dosya kodlayıcı)"
```

---

## Task 4: ConsentProviding (Core) + UserDefaultsConsentStore (Data)

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/Consent.swift`
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/UserDefaultsConsentStore.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/UserDefaultsConsentStoreTests.swift`

- [ ] **Step 1: Protokolü yaz (Core)**

`SmokeTrackerCore/Sources/SmokeTrackerCore/Consent.swift`:

```swift
import Foundation

/// Eğitim verisi toplama izninin durumunu sağlayan/saklayan soyutlama.
/// Gizlilik-önce: varsayılan izin YOKTUR (false).
public protocol ConsentProviding: AnyObject {
    var trainingDataConsent: Bool { get set }
}
```

- [ ] **Step 2: Failing test yaz (Data)**

`SmokeTrackerData/Tests/SmokeTrackerDataTests/UserDefaultsConsentStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct UserDefaultsConsentStoreTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "consent-test-\(UUID().uuidString)")!
    }

    @Test func defaultsToNoConsent() {
        let store = UserDefaultsConsentStore(defaults: makeDefaults())
        #expect(store.trainingDataConsent == false)
    }

    @Test func persistsConsentAcrossInstances() {
        let defaults = makeDefaults()
        let store = UserDefaultsConsentStore(defaults: defaults)
        store.trainingDataConsent = true
        #expect(store.trainingDataConsent == true)

        // Aynı defaults ile yeni örnek de kalıcı değeri görmeli.
        let reopened = UserDefaultsConsentStore(defaults: defaults)
        #expect(reopened.trainingDataConsent == true)
    }
}
```

- [ ] **Step 3: Testin başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerData --filter UserDefaultsConsentStoreTests`
Expected: FAIL — `cannot find 'UserDefaultsConsentStore' in scope`.

- [ ] **Step 4: Minimal implementasyon yaz (Data)**

`SmokeTrackerData/Sources/SmokeTrackerData/UserDefaultsConsentStore.swift`:

```swift
import Foundation
import SmokeTrackerCore

/// İzin durumunu UserDefaults'ta saklar. Varsayılan: izin yok (false).
public final class UserDefaultsConsentStore: ConsentProviding {
    private let defaults: UserDefaults
    private let key = "training_data_consent"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var trainingDataConsent: Bool {
        get { defaults.bool(forKey: key) }   // anahtar yoksa false
        set { defaults.set(newValue, forKey: key) }
    }
}
```

- [ ] **Step 5: Testin geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerData --filter UserDefaultsConsentStoreTests`
Expected: PASS (2 test).

- [ ] **Step 6: Tüm paket testlerini doğrula (regresyon)**

Run: `swift test --package-path SmokeTrackerCore && swift test --package-path SmokeTrackerData`
Expected: Her iki pakette de tüm testler PASS.

- [ ] **Step 7: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/Consent.swift \
        SmokeTrackerData/Sources/SmokeTrackerData/UserDefaultsConsentStore.swift \
        SmokeTrackerData/Tests/SmokeTrackerDataTests/UserDefaultsConsentStoreTests.swift
git commit -m "feat: ConsentProviding protokolü + UserDefaults izin deposu"
```

---

## Task 5: AccelerometerMotionRecorder (watch, CMSensorRecorder)

Donanıma bağlı; **yalnızca derleme** ile doğrulanır. `MotionRecording` sözleşmesi senkron olduğundan, `stopRecording()` kayıt penceresi için en iyi-çaba (best-effort) senkron çekme yapar.

**Files:**
- Create: `SmokeTrackerApp/Watch/AccelerometerMotionRecorder.swift`
- Modify: `SmokeTrackerApp/Watch/Info.plist`

- [ ] **Step 1: Motion kullanım açıklamasını ekle**

`SmokeTrackerApp/Watch/Info.plist` içinde `</dict>` kapanışından hemen önce şu anahtarı ekle:

```xml
    <key>NSMotionUsageDescription</key>
    <string>Sensörlü seans sırasında bilek hareketini kaydederek ileride sigara içme hareketini otomatik tanımak için kullanılır. Yalnızca açık izninle toplanır.</string>
```

- [ ] **Step 2: CMSensorRecorder adaptörünü yaz**

`SmokeTrackerApp/Watch/AccelerometerMotionRecorder.swift`:

```swift
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

    func startRecording() {
        startedAt = Date()
        // İlk çağrı, gerekiyorsa Motion & Fitness iznini tetikler.
        recorder.recordAccelerometer(forDuration: plannedDuration)
    }

    func stopRecording() -> [MotionSample] {
        guard let start = startedAt else { return [] }
        startedAt = nil
        guard let list = recorder.accelerometerData(from: start, to: Date()) else { return [] }

        var samples: [MotionSample] = []
        for case let data as CMRecordedAccelerometerData in list {
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
```

- [ ] **Step 3: Projeyi yeniden üret ve derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker \
  -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add SmokeTrackerApp/Watch/AccelerometerMotionRecorder.swift \
        SmokeTrackerApp/Watch/Info.plist \
        SmokeTrackerApp/SmokeTracker.xcodeproj/project.pbxproj
git commit -m "feat(watch): CMSensorRecorder ile MotionRecording gerçeklemesi + Motion izni açıklaması"
```

---

## Task 6: Watch seans ekranı (WatchModel + WatchSyncSender + WatchSessionView)

Tek WCSession delegate kuralı korunur: gönderim mevcut `WatchSyncSender`'a eklenir; yeni delegate yaratılmaz. Tek depo/tek gönderici için seans, ayrı bir model yerine mevcut `WatchModel`'e eklenir.

**Files:**
- Modify: `SmokeTrackerApp/Watch/WatchSyncSender.swift`
- Modify: `SmokeTrackerApp/Watch/WatchModel.swift`
- Create: `SmokeTrackerApp/Watch/WatchSessionView.swift`
- Modify: `SmokeTrackerApp/Watch/WatchTodayView.swift`

- [ ] **Step 1: WatchSyncSender'a eğitim verisi gönderimi ekle**

`SmokeTrackerApp/Watch/WatchSyncSender.swift` (tam yeni içerik):

```swift
import Foundation
import WatchConnectivity
import SmokeTrackerCore
import SmokeTrackerData

/// Yeni olayları ve (izinle) eğitim verisini WCSession ile iPhone'a aktarır.
/// Watch tarafındaki tek WCSession delegate'i; yalnızca MainActor'daki
/// WatchModel'den kullanılır.
@MainActor
final class WatchSyncSender: NSObject, WCSessionDelegate {
    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Tek bir olayı sıraya koyar; karşı taraf erişilemezse bile teslim edilir.
    func send(_ event: SmokingEvent) {
        guard let data = try? SyncMessageCodec.encode([event]) else { return }
        WCSession.default.transferUserInfo(["payload": data])
    }

    /// Ham eğitim verisini dosya olarak gönderir (boyut büyük olabilir).
    func sendTrainingSession(_ session: TrainingSession) {
        guard let data = try? TrainingSessionCodec.encode(session) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("training-\(session.id.uuidString).json")
        do {
            try data.write(to: url, options: .atomic)
            WCSession.default.transferFile(url, metadata: ["type": "trainingSession"])
        } catch {
            #if DEBUG
            print("[WatchSyncSender] eğitim verisi yazılamadı: \(error)")
            #endif
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
```

- [ ] **Step 2: WatchModel'e seans yeteneğini ekle**

`SmokeTrackerApp/Watch/WatchModel.swift` (tam yeni içerik):

```swift
import Foundation
import Observation
import SmokeTrackerCore
import SmokeTrackerData

/// Watch tarafı durum: yerel kayıt, bugünkü sayı, +1 ve opsiyonel sensörlü seans.
@MainActor
@Observable
final class WatchModel {
    private let store: FileEventStore
    private let quickLog: QuickLogManager
    private let sender: WatchSyncSender
    private let stats = StatsEngine(calendar: .current)
    private let consent: UserDefaultsConsentStore
    private let motionRecorder: AccelerometerMotionRecorder
    private let sessionRecorder: SessionRecorder

    var todayCount: Int = 0
    var isRecordingSession: Bool = false
    var trainingDataConsent: Bool {
        didSet { consent.trainingDataConsent = trainingDataConsent }
    }

    init() {
        let url = URL.documentsDirectory.appendingPathComponent("watch-events.json")
        let store = FileEventStore(url: url)
        let consent = UserDefaultsConsentStore()
        let motionRecorder = AccelerometerMotionRecorder()

        self.store = store
        self.quickLog = QuickLogManager(store: store, dateProvider: SystemDateProvider())
        self.sender = WatchSyncSender()
        self.consent = consent
        self.motionRecorder = motionRecorder
        self.sessionRecorder = SessionRecorder(motion: motionRecorder, dateProvider: SystemDateProvider())
        self.trainingDataConsent = consent.trainingDataConsent
        refresh()
    }

    /// +1: yerelde kaydet, iPhone'a gönder, sayıyı güncelle.
    func logOne() {
        let event = quickLog.logOne()
        sender.send(event)
        refresh()
    }

    /// Sensörlü seansı başlatır (ilk kayıt Motion iznini tetikler).
    func startSession() {
        sessionRecorder.start()
        isRecordingSession = true
    }

    /// Seansı bitirir: her zaman +1 işler; izin varsa ham veriyi iPhone'a yollar.
    func stopSession() {
        guard let result = sessionRecorder.stop() else { return }
        isRecordingSession = false

        // Olay kanalı (her zaman): +1 say ve iPhone'a gönder.
        store.add(result.event)
        sender.send(result.event)

        // Eğitim verisi kanalı (yalnızca izinle, en iyi-çaba).
        if trainingDataConsent, !result.samples.isEmpty {
            let training = TrainingSession(
                id: UUID(),
                eventID: result.event.id,
                recordedAt: result.event.timestamp,
                label: "sigara",
                samples: result.samples
            )
            sender.sendTrainingSession(training)
        }
        refresh()
    }

    func refresh() {
        todayCount = stats.count(on: Date(), events: store.allEvents())
    }
}
```

- [ ] **Step 3: Seans ekranını yaz**

`SmokeTrackerApp/Watch/WatchSessionView.swift`:

```swift
import SwiftUI

struct WatchSessionView: View {
    @Bindable var model: WatchModel

    var body: some View {
        VStack(spacing: 12) {
            if model.isRecordingSession {
                Text("Seans kaydı sürüyor")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                ProgressView()
                Button(role: .destructive) {
                    model.stopSession()
                } label: {
                    Label("Bitir (+1)", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
            } else {
                Text("Sensörlü seans")
                    .font(.headline)
                Text("Başlat; içerken bilek hareketini kaydedelim, bitince +1 işlenir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    model.startSession()
                } label: {
                    Label("Seans başlat", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Toggle("Eğitim verisi topla", isOn: $model.trainingDataConsent)
                    .font(.caption)
            }
        }
        .padding()
        .navigationTitle("Seans")
    }
}
```

- [ ] **Step 4: Bugün ekranından seansa link ekle**

`SmokeTrackerApp/Watch/WatchTodayView.swift` (tam yeni içerik):

```swift
import SwiftUI

struct WatchTodayView: View {
    let model: WatchModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("\(model.todayCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("bugün")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    model.logOne()
                } label: {
                    Label("Sigara", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                NavigationLink {
                    WatchSessionView(model: model)
                } label: {
                    Label("Seans", systemImage: "record.circle")
                }
            }
            .padding()
        }
    }
}
```

- [ ] **Step 5: Projeyi yeniden üret ve derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker \
  -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SmokeTrackerApp/Watch/WatchSyncSender.swift \
        SmokeTrackerApp/Watch/WatchModel.swift \
        SmokeTrackerApp/Watch/WatchSessionView.swift \
        SmokeTrackerApp/Watch/WatchTodayView.swift \
        SmokeTrackerApp/SmokeTracker.xcodeproj/project.pbxproj
git commit -m "feat(watch): sensörlü seans ekranı, +1 ve izinli eğitim verisi gönderimi"
```

---

## Task 7: iPhone eğitim verisi alımı + yönetimi (PhoneSyncReceiver + PhoneModel + TrainingDataView)

Tek WCSession delegate kuralı korunur: dosya alımı mevcut `PhoneSyncReceiver`'a eklenir.

**Files:**
- Modify: `SmokeTrackerApp/iOS/PhoneSyncReceiver.swift`
- Modify: `SmokeTrackerApp/iOS/PhoneModel.swift`
- Create: `SmokeTrackerApp/iOS/TrainingDataView.swift`
- Modify: `SmokeTrackerApp/iOS/TodayView.swift`

- [ ] **Step 1: PhoneSyncReceiver'a dosya alımı ekle**

`SmokeTrackerApp/iOS/PhoneSyncReceiver.swift` (tam yeni içerik):

```swift
import Foundation
import WatchConnectivity
import SmokeTrackerCore
import SmokeTrackerData

/// Watch'tan gelen olayları (userInfo) ve eğitim verisini (file) alır.
/// iPhone tarafındaki tek WCSession delegate'i. Delegate çağrıları arka planda
/// gelir; işleme MainActor'a taşınır.
@MainActor
final class PhoneSyncReceiver: NSObject, WCSessionDelegate {
    private let coordinator: SyncCoordinator
    private let archive: TrainingDataArchiving
    private let onChange: () -> Void

    init(
        coordinator: SyncCoordinator,
        archive: TrainingDataArchiving,
        onChange: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.archive = archive
        self.onChange = onChange
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["payload"] as? Data,
              let events = try? SyncMessageCodec.decode(data) else { return }
        Task { @MainActor in
            for event in events {
                self.coordinator.ingest(event)
            }
            self.onChange()
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // fileURL yalnızca bu çağrı süresince geçerlidir; hemen oku ve çöz.
        guard let data = try? Data(contentsOf: file.fileURL),
              let training = try? TrainingSessionCodec.decode(data) else { return }
        Task { @MainActor in
            try? self.archive.save(training)
            self.onChange()
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
```

- [ ] **Step 2: PhoneModel'e arşiv + izin + seansları ekle**

`SmokeTrackerApp/iOS/PhoneModel.swift` (tam yeni içerik):

```swift
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
    private let stats = StatsEngine(calendar: .current)
    private var receiver: PhoneSyncReceiver?

    var todayCount: Int = 0
    var weekCount: Int = 0
    var history: [SmokingEvent] = []
    var trainingSessions: [TrainingSession] = []
    var trainingDataConsent: Bool {
        didSet { consent.trainingDataConsent = trainingDataConsent }
    }

    init() {
        let container: ModelContainer
        do {
            container = try EventStoreFactory.makePersistentContainer()
        } catch {
            // Kalıcı depo bozuksa uygulama açılışta çökmesin diye bellek-içine düş.
            container = try! EventStoreFactory.makeInMemoryContainer()
        }
        let store = SwiftDataEventStore(context: ModelContext(container))
        let archiveDir = URL.documentsDirectory.appendingPathComponent("training", isDirectory: true)
        let archive = FileTrainingDataArchive(directory: archiveDir)

        self.store = store
        self.coordinator = SyncCoordinator(store: store)
        self.archive = archive
        self.trainingDataConsent = consent.trainingDataConsent
        refresh()
        self.receiver = PhoneSyncReceiver(coordinator: coordinator, archive: archive) { [weak self] in
            self?.refresh()
        }
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
}
```

- [ ] **Step 3: Eğitim verisi yönetim ekranını yaz**

`SmokeTrackerApp/iOS/TrainingDataView.swift`:

```swift
import SwiftUI
import SmokeTrackerCore

struct TrainingDataView: View {
    @Bindable var model: PhoneModel

    var body: some View {
        List {
            Section {
                Toggle("Eğitim verisi toplamaya izin ver", isOn: $model.trainingDataConsent)
                Text("Sensörlü seanslardaki ham hareket verisi, ileride sigara içme hareketini otomatik tanımak için kullanılacak. Yalnızca açık izninle saklanır; istediğin an silebilirsin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Kayıtlı seanslar (\(model.trainingSessions.count))") {
                if model.trainingSessions.isEmpty {
                    Text("Henüz kayıt yok")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.trainingSessions) { session in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.recordedAt, format: .dateTime.day().month().hour().minute())
                            Text("\(session.samples.count) örnek")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { model.trainingSessions[$0] }
                            .forEach(model.deleteTrainingSession)
                    }
                    Button(role: .destructive) {
                        model.deleteAllTrainingData()
                    } label: {
                        Text("Tüm eğitim verisini sil")
                    }
                }
            }
        }
        .navigationTitle("Eğitim verisi")
    }
}
```

- [ ] **Step 4: Bugün ekranından eğitim verisine link ekle**

`SmokeTrackerApp/iOS/TodayView.swift` (tam yeni içerik):

```swift
import SwiftUI

struct TodayView: View {
    let model: PhoneModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Bugün")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(model.todayCount)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                Text("Bu hafta: \(model.weekCount)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    HistoryView(events: model.history)
                } label: {
                    Label("Geçmiş", systemImage: "list.bullet")
                }
                .padding(.top, 8)
                NavigationLink {
                    TrainingDataView(model: model)
                } label: {
                    Label("Eğitim verisi", systemImage: "waveform.path.ecg")
                }
            }
            .padding()
            .navigationTitle("Sigara Takip")
        }
    }
}
```

- [ ] **Step 5: Projeyi yeniden üret ve derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker \
  -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SmokeTrackerApp/iOS/PhoneSyncReceiver.swift \
        SmokeTrackerApp/iOS/PhoneModel.swift \
        SmokeTrackerApp/iOS/TrainingDataView.swift \
        SmokeTrackerApp/iOS/TodayView.swift \
        SmokeTrackerApp/SmokeTracker.xcodeproj/project.pbxproj
git commit -m "feat(ios): eğitim verisi alımı (dosya), arşiv ve onay/yönetim ekranı"
```

---

## Task 8: Gün sınırı yenilemesi + uçtan uca derleme doğrulaması + hafıza güncelle

Uygulama gece yarısını açıkken geçerse "bugün" sayısı yenilensin: her iki app öne geldiğinde `refresh()` çağrılır.

**Files:**
- Modify: `SmokeTrackerApp/iOS/SmokeTrackerApp.swift`
- Modify: `SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift`

- [ ] **Step 1: iOS app girişine scenePhase yenilemesi ekle**

`SmokeTrackerApp/iOS/SmokeTrackerApp.swift` (tam yeni içerik):

```swift
import SwiftUI

@main
struct SmokeTrackerApp: App {
    @State private var model = PhoneModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TodayView(model: model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }
}
```

- [ ] **Step 2: watch app girişine scenePhase yenilemesi ekle**

`SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift` (tam yeni içerik):

```swift
import SwiftUI

@main
struct SmokeTrackerWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchTodayView(model: model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }
}
```

- [ ] **Step 3: Tüm paket testleri (regresyon)**

```bash
swift test --package-path SmokeTrackerCore
swift test --package-path SmokeTrackerData
```

Expected: Her iki pakette de tüm testler PASS.

- [ ] **Step 4: Projeyi yeniden üret ve derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker \
  -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerApp/iOS/SmokeTrackerApp.swift \
        SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift \
        SmokeTrackerApp/SmokeTracker.xcodeproj/project.pbxproj
git commit -m "feat(app): öne gelince gün sınırı için sayıyı yenile"
```

- [ ] **Step 6: Proje hafızasını güncelle**

`/Users/batu/.claude/projects/-Users-batu-projeler/memory/smoke-tracker-project.md` içindeki durum bölümünü Plan 3 TAMAM olarak güncelle ve Plan 4 kapsamını (complication + onboarding/izin/gizlilik) yaz.

---

## Bilinçli kapsam dışı (YAGNI / sonraki planlar)

- **Complication** (kadrandan tek dokunuş) — Plan 4 (WidgetKit accessory widget hedefi gerektirir).
- **Tam onboarding + ayrı gizlilik ekranı + proaktif izin isteği** — Plan 4. Plan 3'teki seans-içi toggle yeterli minimal onaydır.
- **Gecikmeli/arka plan sensör verisi çekme** (CMSensorRecorder verisinin tamamını sonradan toplama) — Faz 2. Plan 3 en iyi-çaba senkron çekme yapar.
- **iPhone→watch geri senkron** — Plan 3'te gerekmez: olayların kaynağı yalnızca watch'tır (iPhone olay üretmez). İki yönlü senkron, iPhone'a +1 girişi eklendiğinde değerlendirilecek.
- **HKWorkoutSession ile zengin (accel+gyro) kayıt** — Faz 2/3.
- **Seans için otomatik hareketsizlik-bitişi** — Faz 2 (şimdilik elle "Bitir").

## Test stratejisi özeti

- **Test edilebilir (TDD, `swift test`):** TrainingSession codable round-trip; FileTrainingDataArchive CRUD + sıralama; TrainingSessionCodec round-trip; UserDefaultsConsentStore varsayılan-kapalı + kalıcılık.
- **Yalnızca derleme (bu ortam):** CMSensorRecorder adaptörü, watch seans UI'ı + gönderim, iPhone dosya alımı + yönetim UI'ı, scenePhase yenilemesi.
- **Ertelenen (kullanıcı ortamı düzelince):** Eşli iPhone+Watch simülatöründe seans başlat→bitir→iPhone arşivinde seansın belirmesi; izin reddinde +1'in çalışmaya devam etmesi; gece yarısı sayaç sıfırlanması.
