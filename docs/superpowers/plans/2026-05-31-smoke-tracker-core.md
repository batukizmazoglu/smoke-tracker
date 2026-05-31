# SmokeTrackerCore (Çekirdek Mantık) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sigara/IQOS takip uygulamasının platform-bağımsız çekirdek mantığını (model, istatistik, senkron-dedup, hızlı kayıt, seans durum makinesi) tam test kapsamıyla bir Swift Package olarak inşa etmek.

**Architecture:** Tüm test edilebilir iş mantığı `SmokeTrackerCore` adlı bir SPM paketinde toplanır; UIKit/SwiftUI/CoreMotion/WatchConnectivity/SwiftData gibi platforma özgü bağımlılıklar yoktur. Platform entegrasyonları (Plan 2 & 3) bu pakette tanımlı protokolleri (`EventStoring`, `DateProviding`, `MotionRecording`) gerçekleyecek. Bu sayede çekirdek mantık `swift test` ile macOS host üzerinde, simülatör gerektirmeden, deterministik biçimde test edilir.

**Tech Stack:** Swift 6.3 (tools-version 6.0), Swift Package Manager, Swift Testing (`import Testing`), Foundation. Xcode 26.5 / macOS.

---

## Proje yol haritası (plan ayrıştırması)

Bu MVP üç ardışık plana bölünmüştür. Bu doküman **Plan 1**'dir.

| Plan | Kapsam | Test edilebilirlik |
|------|--------|--------------------|
| **Plan 1 (bu)** — SmokeTrackerCore | Model, `StatsEngine`, `SyncCoordinator`, `QuickLogManager`, `SessionRecorder` + protokoller | Tam TDD, `swift test` (CLI) |
| **Plan 2** — App kabuğu + kalıcılık + senkron | Xcode iOS+watchOS hedefleri, `SwiftData` `EventStore`, `WatchConnectivity` senkronu, temel SwiftUI ekranları | Kısmi (SwiftData entegrasyon testleri + manuel) |
| **Plan 3** — Giriş noktaları + sensör + gizlilik | Complication, `CMSensorRecorder` ile `MotionRecording` gerçeklemesi, `TrainingDataArchive`, onboarding/izinler | Çoğunlukla manuel + entegrasyon |

Her plan tek başına çalışan, derlenen ve (Plan 1 için) tamamen test edilen yazılım üretir.

---

## Dosya yapısı (Plan 1)

```
smoke-tracker/
  SmokeTrackerCore/
    Package.swift
    Sources/SmokeTrackerCore/
      CoreInfo.swift          # paket sürüm sabiti (bootstrap)
      SmokingEvent.swift      # SmokingEvent modeli + EventSource enum
      Protocols.swift         # EventStoring + DateProviding (+ SystemDateProvider)
      StatsEngine.swift       # günlük/haftalık sayım (saf fonksiyonlar)
      SyncCoordinator.swift   # idempotent/dedup olay alımı
      QuickLogManager.swift   # tek dokunuş +1 mantığı
      Motion.swift            # MotionSample + MotionRecording protokolü
      SessionRecorder.swift   # seans durum makinesi (idle/recording/finished)
    Tests/SmokeTrackerCoreTests/
      CoreInfoTests.swift
      SmokingEventTests.swift
      TestHelpers.swift       # FixedDateProvider, InMemoryEventStore, date() yardımcıları
      StatsEngineTests.swift
      SyncCoordinatorTests.swift
      QuickLogManagerTests.swift
      SessionRecorderTests.swift
```

Her dosya tek sorumluluk taşır. Komutlar depo kökünden (`smoke-tracker/`) çalıştırılır; pakete `--package-path SmokeTrackerCore` ile erişilir.

---

### Task 1: Swift paketini başlat (bootstrap)

**Files:**
- Create: `SmokeTrackerCore/Package.swift`
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/CoreInfo.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/CoreInfoTests.swift`

- [ ] **Step 1: Package.swift dosyasını oluştur**

`SmokeTrackerCore/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SmokeTrackerCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SmokeTrackerCore", targets: ["SmokeTrackerCore"]),
    ],
    targets: [
        .target(name: "SmokeTrackerCore"),
        .testTarget(
            name: "SmokeTrackerCoreTests",
            dependencies: ["SmokeTrackerCore"]
        ),
    ]
)
```

- [ ] **Step 2: Kaynak dosyayı oluştur**

`SmokeTrackerCore/Sources/SmokeTrackerCore/CoreInfo.swift`:

```swift
public enum CoreInfo {
    public static let version = "0.1.0"
}
```

- [ ] **Step 3: Failing test'i yaz**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/CoreInfoTests.swift`:

```swift
import Testing
@testable import SmokeTrackerCore

@Suite struct CoreInfoTests {
    @Test func exposesVersion() {
        #expect(CoreInfo.version == "0.1.0")
    }
}
```

- [ ] **Step 4: Testi çalıştır (geçmeli — bootstrap doğrulaması)**

Run: `swift test --package-path SmokeTrackerCore --filter CoreInfoTests`
Expected: PASS — `1 test passed`. (Bu görev altyapı kurar; testin amacı paketin derlenip test koşucusunun çalıştığını doğrulamaktır.)

- [ ] **Step 5: .gitignore ekle ve commit'le**

`SmokeTrackerCore/.gitignore`:

```
.build/
.swiftpm/
```

```bash
git add SmokeTrackerCore/Package.swift SmokeTrackerCore/Sources SmokeTrackerCore/Tests SmokeTrackerCore/.gitignore
git commit -m "feat(core): SmokeTrackerCore Swift paketini başlat"
```

---

### Task 2: SmokingEvent modeli

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/SmokingEvent.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SmokingEventTests.swift`

- [ ] **Step 1: Failing test'i yaz**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SmokingEventTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct SmokingEventTests {
    @Test func storesProvidedValues() {
        let id = UUID()
        let ts = Date(timeIntervalSince1970: 1_700_000_000)
        let event = SmokingEvent(id: id, timestamp: ts, source: .tap)

        #expect(event.id == id)
        #expect(event.timestamp == ts)
        #expect(event.source == .tap)
    }

    @Test func isCodableRoundTrip() throws {
        let event = SmokingEvent(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            source: .session
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(SmokingEvent.self, from: data)
        #expect(decoded == event)
    }
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter SmokingEventTests`
Expected: FAIL — derleme hatası `cannot find 'SmokingEvent' in scope`.

- [ ] **Step 3: Minimal implementasyonu yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/SmokingEvent.swift`:

```swift
import Foundation

/// Tek bir sigara/IQOS olayının kaynağı.
public enum EventSource: String, Codable, Sendable, Equatable {
    case tap        // tek dokunuşla manuel kayıt
    case session    // sensörlü seanstan üretildi
}

/// Tek bir sigara/IQOS olayı (1 olay = 1 çubuk).
public struct SmokingEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource

    public init(id: UUID, timestamp: Date, source: EventSource) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
    }
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter SmokingEventTests`
Expected: PASS — `2 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/SmokingEvent.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SmokingEventTests.swift
git commit -m "feat(core): SmokingEvent modeli ve EventSource"
```

---

### Task 3: Protokoller + test yardımcıları

EventStoring ve DateProviding soyutlamalarını ve testlerde tekrar kullanılacak yardımcıları (in-memory store, sabit tarih sağlayıcı, tarih oluşturucu) tanımlar. Not: protokol adı için standart kütüphanedeki `Clock` ile çakışmamak adına `DateProviding` kullanılır.

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/Protocols.swift`
- Create: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/TestHelpers.swift`

- [ ] **Step 1: Failing test'i yaz (yardımcıları doğrulayan)**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/TestHelpers.swift`:

```swift
import Foundation
import Testing
@testable import SmokeTrackerCore

// MARK: - Paylaşılan test yardımcıları

/// Sabit bir tarih döndüren DateProviding gerçeklemesi.
final class FixedDateProvider: DateProviding {
    var fixed: Date
    init(_ fixed: Date) { self.fixed = fixed }
    func now() -> Date { fixed }
}

/// Bellek içi EventStoring gerçeklemesi.
final class InMemoryEventStore: EventStoring {
    private(set) var events: [SmokingEvent] = []
    func allEvents() -> [SmokingEvent] { events }
    func add(_ event: SmokingEvent) { events.append(event) }
    func contains(id: UUID) -> Bool { events.contains { $0.id == id } }
}

/// Belirli bir zaman dilimi ve takvimde deterministik tarih üretir.
func makeDate(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int = 12, _ minute: Int = 0,
    timeZone: TimeZone = TimeZone(identifier: "Europe/Istanbul")!
) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    return cal.date(from: comps)!
}

/// İstatistik testleri için Pazartesi-başlangıçlı, sabit zaman dilimli takvim.
func makeCalendar(
    timeZone: TimeZone = TimeZone(identifier: "Europe/Istanbul")!
) -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    cal.firstWeekday = 2 // Pazartesi
    return cal
}

// MARK: - Yardımcıların kendi testi

@Suite struct TestHelpersTests {
    @Test func inMemoryStoreAddsAndDeduplicatesLookup() {
        let store = InMemoryEventStore()
        let id = UUID()
        let event = SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31), source: .tap)

        #expect(store.contains(id: id) == false)
        store.add(event)
        #expect(store.contains(id: id) == true)
        #expect(store.allEvents().count == 1)
    }

    @Test func fixedDateProviderReturnsFixedValue() {
        let d = makeDate(2026, 5, 31, 9, 0)
        let provider = FixedDateProvider(d)
        #expect(provider.now() == d)
    }
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter TestHelpersTests`
Expected: FAIL — derleme hatası `cannot find type 'DateProviding' in scope` ve `cannot find type 'EventStoring' in scope`.

- [ ] **Step 3: Protokolleri yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/Protocols.swift`:

```swift
import Foundation

/// Şu anki zamanı sağlayan soyutlama (test edilebilirlik için).
public protocol DateProviding {
    func now() -> Date
}

/// Gerçek sistem saatini kullanan varsayılan sağlayıcı.
public struct SystemDateProvider: DateProviding {
    public init() {}
    public func now() -> Date { Date() }
}

/// Sigara olaylarının kalıcı deposu için soyutlama.
/// Plan 2'de SwiftData ile gerçeklenecek.
public protocol EventStoring {
    func allEvents() -> [SmokingEvent]
    func add(_ event: SmokingEvent)
    func contains(id: UUID) -> Bool
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter TestHelpersTests`
Expected: PASS — `2 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/Protocols.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/TestHelpers.swift
git commit -m "feat(core): EventStoring/DateProviding protokolleri ve test yardımcıları"
```

---

### Task 4: StatsEngine (günlük/haftalık sayım)

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/StatsEngine.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/StatsEngineTests.swift`

- [ ] **Step 1: Failing test'i yaz**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/StatsEngineTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct StatsEngineTests {
    private func event(_ date: Date, _ source: EventSource = .tap) -> SmokingEvent {
        SmokingEvent(id: UUID(), timestamp: date, source: source)
    }

    @Test func countsEventsOnGivenDayRespectingTimeZone() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 31, 9, 0)),
            event(makeDate(2026, 5, 31, 14, 0)),
            event(makeDate(2026, 5, 31, 23, 30)),
            event(makeDate(2026, 6, 1, 0, 30)),   // ertesi gün (yerel)
        ]

        let count = engine.count(on: makeDate(2026, 5, 31, 12, 0), events: events)
        #expect(count == 3)
    }

    @Test func dailyCountsGroupsAndSortsAscending() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 6, 1, 0, 30)),
            event(makeDate(2026, 5, 31, 9, 0)),
            event(makeDate(2026, 5, 31, 14, 0)),
            event(makeDate(2026, 5, 31, 23, 30)),
        ]

        let daily = engine.dailyCounts(events: events)
        #expect(daily.count == 2)
        #expect(daily[0].count == 3)
        #expect(daily[1].count == 1)
        #expect(daily[0].day < daily[1].day)
    }

    @Test func countInWeekIncludesOnlySameWeek() {
        let engine = StatsEngine(calendar: makeCalendar())
        let events = [
            event(makeDate(2026, 5, 25, 10, 0)), // Pazartesi
            event(makeDate(2026, 5, 27, 10, 0)),
            event(makeDate(2026, 5, 31, 23, 0)), // Pazar (aynı hafta)
            event(makeDate(2026, 6, 2, 10, 0)),  // sonraki hafta
        ]

        let count = engine.countInWeek(containing: makeDate(2026, 5, 27, 12, 0), events: events)
        #expect(count == 3)
    }

    @Test func emptyEventsYieldZero() {
        let engine = StatsEngine(calendar: makeCalendar())
        #expect(engine.count(on: makeDate(2026, 5, 31), events: []) == 0)
        #expect(engine.dailyCounts(events: []).isEmpty)
    }
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter StatsEngineTests`
Expected: FAIL — derleme hatası `cannot find 'StatsEngine' in scope`.

- [ ] **Step 3: Minimal implementasyonu yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/StatsEngine.swift`:

```swift
import Foundation

/// Bir günün toplam sayısı.
public struct DailyCount: Equatable, Sendable {
    public let day: Date   // günün başlangıcı (startOfDay)
    public let count: Int

    public init(day: Date, count: Int) {
        self.day = day
        self.count = count
    }
}

/// Olay listesinden günlük/haftalık sayımlar üreten saf hesaplayıcı.
public struct StatsEngine {
    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// Verilen güne (yerel takvime göre) ait olay sayısı.
    public func count(on day: Date, events: [SmokingEvent]) -> Int {
        events.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.count
    }

    /// Olayları güne göre gruplayıp artan sırada döndürür.
    public func dailyCounts(events: [SmokingEvent]) -> [DailyCount] {
        let groups = Dictionary(grouping: events) { calendar.startOfDay(for: $0.timestamp) }
        return groups
            .map { DailyCount(day: $0.key, count: $0.value.count) }
            .sorted { $0.day < $1.day }
    }

    /// Verilen tarihin içinde bulunduğu haftanın toplam sayısı.
    public func countInWeek(containing date: Date, events: [SmokingEvent]) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return events.filter { interval.contains($0.timestamp) }.count
    }
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter StatsEngineTests`
Expected: PASS — `4 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/StatsEngine.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/StatsEngineTests.swift
git commit -m "feat(core): StatsEngine günlük/haftalık sayım"
```

---

### Task 5: SyncCoordinator (idempotent/dedup alım)

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/SyncCoordinator.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SyncCoordinatorTests.swift`

- [ ] **Step 1: Failing test'i yaz**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SyncCoordinatorTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct SyncCoordinatorTests {
    @Test func ingestsNewEvent() {
        let store = InMemoryEventStore()
        let coordinator = SyncCoordinator(store: store)
        let event = SmokingEvent(id: UUID(), timestamp: makeDate(2026, 5, 31), source: .tap)

        let inserted = coordinator.ingest(event)

        #expect(inserted == true)
        #expect(store.allEvents().count == 1)
    }

    @Test func ignoresDuplicateId() {
        let store = InMemoryEventStore()
        let coordinator = SyncCoordinator(store: store)
        let id = UUID()
        let first = SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31, 9, 0), source: .tap)
        let dup = SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31, 9, 1), source: .tap)

        #expect(coordinator.ingest(first) == true)
        #expect(coordinator.ingest(dup) == false)
        #expect(store.allEvents().count == 1)
    }

    @Test func ingestBatchDeduplicates() {
        let store = InMemoryEventStore()
        let coordinator = SyncCoordinator(store: store)
        let id = UUID()
        let batch = [
            SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31, 9, 0), source: .tap),
            SmokingEvent(id: id, timestamp: makeDate(2026, 5, 31, 9, 0), source: .tap),
            SmokingEvent(id: UUID(), timestamp: makeDate(2026, 5, 31, 10, 0), source: .tap),
        ]

        coordinator.ingest(batch)

        #expect(store.allEvents().count == 2)
    }
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter SyncCoordinatorTests`
Expected: FAIL — derleme hatası `cannot find 'SyncCoordinator' in scope`.

- [ ] **Step 3: Minimal implementasyonu yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/SyncCoordinator.swift`:

```swift
import Foundation

/// Watch'tan gelen olayları ana depoya idempotent biçimde aktarır.
/// Aynı `id`'li olay birden çok kez gelse bile tek kez saklanır.
public final class SyncCoordinator {
    private let store: EventStoring

    public init(store: EventStoring) {
        self.store = store
    }

    /// Tek olayı alır. Yeni eklendiyse `true`, zaten varsa `false` döner.
    @discardableResult
    public func ingest(_ event: SmokingEvent) -> Bool {
        guard !store.contains(id: event.id) else { return false }
        store.add(event)
        return true
    }

    /// Olay dizisini sırayla alır; tekrarları otomatik eler.
    public func ingest(_ events: [SmokingEvent]) {
        for event in events {
            ingest(event)
        }
    }
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter SyncCoordinatorTests`
Expected: PASS — `3 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/SyncCoordinator.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SyncCoordinatorTests.swift
git commit -m "feat(core): SyncCoordinator idempotent olay alımı"
```

---

### Task 6: QuickLogManager (tek dokunuş +1)

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/QuickLogManager.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/QuickLogManagerTests.swift`

- [ ] **Step 1: Failing test'i yaz**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/QuickLogManagerTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct QuickLogManagerTests {
    @Test func logOneCreatesTapEventWithProviderValues() {
        let store = InMemoryEventStore()
        let fixedDate = makeDate(2026, 5, 31, 9, 0)
        let fixedID = UUID()
        let manager = QuickLogManager(
            store: store,
            dateProvider: FixedDateProvider(fixedDate),
            idProvider: { fixedID }
        )

        let event = manager.logOne()

        #expect(event.id == fixedID)
        #expect(event.timestamp == fixedDate)
        #expect(event.source == .tap)
        #expect(store.allEvents().count == 1)
        #expect(store.allEvents().first == event)
    }

    @Test func multipleLogsAccumulate() {
        let store = InMemoryEventStore()
        var counter = 0
        let manager = QuickLogManager(
            store: store,
            dateProvider: FixedDateProvider(makeDate(2026, 5, 31, 9, 0)),
            idProvider: {
                counter += 1
                return UUID(uuidString: "00000000-0000-0000-0000-00000000000\(counter)")!
            }
        )

        manager.logOne()
        manager.logOne()
        manager.logOne()

        #expect(store.allEvents().count == 3)
    }
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter QuickLogManagerTests`
Expected: FAIL — derleme hatası `cannot find 'QuickLogManager' in scope`.

- [ ] **Step 3: Minimal implementasyonu yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/QuickLogManager.swift`:

```swift
import Foundation

/// Tek dokunuşla anında +1 kaydı oluşturur (kaynak: .tap).
public final class QuickLogManager {
    private let store: EventStoring
    private let dateProvider: DateProviding
    private let idProvider: () -> UUID

    public init(
        store: EventStoring,
        dateProvider: DateProviding,
        idProvider: @escaping () -> UUID = { UUID() }
    ) {
        self.store = store
        self.dateProvider = dateProvider
        self.idProvider = idProvider
    }

    /// Yeni bir tap olayı oluşturup depoya ekler ve döndürür.
    @discardableResult
    public func logOne() -> SmokingEvent {
        let event = SmokingEvent(
            id: idProvider(),
            timestamp: dateProvider.now(),
            source: .tap
        )
        store.add(event)
        return event
    }
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter QuickLogManagerTests`
Expected: PASS — `2 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/QuickLogManager.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/QuickLogManagerTests.swift
git commit -m "feat(core): QuickLogManager tek dokunuş kaydı"
```

---

### Task 7: MotionRecording protokolü + SessionRecorder durum makinesi

Seansın deterministik durum makinesini (idle → recording → finished) ve sensör soyutlamasını kurar. Gerçek `CMSensorRecorder` gerçeklemesi Plan 3'tedir; burada `MotionRecording` protokolü mock'lanır.

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/Motion.swift`
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/SessionRecorder.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SessionRecorderTests.swift`

- [ ] **Step 1: Failing test'i yaz**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SessionRecorderTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

/// Önceden tanımlı örnekler döndüren sahte MotionRecording.
final class MockMotionRecorder: MotionRecording {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    var samplesToReturn: [MotionSample]

    init(samplesToReturn: [MotionSample] = []) {
        self.samplesToReturn = samplesToReturn
    }

    func startRecording() { startCallCount += 1 }
    func stopRecording() -> [MotionSample] {
        stopCallCount += 1
        return samplesToReturn
    }
}

@Suite struct SessionRecorderTests {
    private func sample(_ t: Double) -> MotionSample {
        MotionSample(timestamp: Date(timeIntervalSince1970: t), x: 0.1, y: 0.2, z: 0.3)
    }

    @Test func startsRecordingFromIdle() {
        let motion = MockMotionRecorder()
        let recorder = SessionRecorder(
            motion: motion,
            dateProvider: FixedDateProvider(makeDate(2026, 5, 31, 9, 0))
        )

        #expect(recorder.state == .idle)
        recorder.start()
        #expect(recorder.state == .recording)
        #expect(motion.startCallCount == 1)
    }

    @Test func stopProducesSessionEventAndSamples() {
        let samples = [sample(1), sample(2)]
        let motion = MockMotionRecorder(samplesToReturn: samples)
        let fixedDate = makeDate(2026, 5, 31, 9, 0)
        let fixedID = UUID()
        let recorder = SessionRecorder(
            motion: motion,
            dateProvider: FixedDateProvider(fixedDate),
            idProvider: { fixedID }
        )

        recorder.start()
        let result = recorder.stop()

        #expect(recorder.state == .finished)
        #expect(motion.stopCallCount == 1)
        #expect(result?.event.id == fixedID)
        #expect(result?.event.timestamp == fixedDate)
        #expect(result?.event.source == .session)
        #expect(result?.samples == samples)
    }

    @Test func startIsNoOpWhenAlreadyRecording() {
        let motion = MockMotionRecorder()
        let recorder = SessionRecorder(
            motion: motion,
            dateProvider: FixedDateProvider(makeDate(2026, 5, 31, 9, 0))
        )

        recorder.start()
        recorder.start()

        #expect(motion.startCallCount == 1)
        #expect(recorder.state == .recording)
    }

    @Test func stopReturnsNilWhenIdle() {
        let motion = MockMotionRecorder()
        let recorder = SessionRecorder(
            motion: motion,
            dateProvider: FixedDateProvider(makeDate(2026, 5, 31, 9, 0))
        )

        let result = recorder.stop()

        #expect(result == nil)
        #expect(motion.stopCallCount == 0)
        #expect(recorder.state == .idle)
    }
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter SessionRecorderTests`
Expected: FAIL — derleme hatası `cannot find type 'MotionRecording' in scope` ve `cannot find 'SessionRecorder' in scope`.

- [ ] **Step 3: Motion soyutlamasını yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/Motion.swift`:

```swift
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
```

- [ ] **Step 4: SessionRecorder'ı yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/SessionRecorder.swift`:

```swift
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

    /// Seansı başlatır. Zaten kayıttaysa hiçbir şey yapmaz.
    public func start() {
        guard state == .idle else { return }
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
```

- [ ] **Step 5: Testi çalıştır, geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerCore --filter SessionRecorderTests`
Expected: PASS — `4 tests passed`.

- [ ] **Step 6: Tüm test paketini çalıştır (regresyon kontrolü)**

Run: `swift test --package-path SmokeTrackerCore`
Expected: PASS — tüm testler geçer (yaklaşık 17 test).

- [ ] **Step 7: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/Motion.swift SmokeTrackerCore/Sources/SmokeTrackerCore/SessionRecorder.swift SmokeTrackerCore/Tests/SmokeTrackerCoreTests/SessionRecorderTests.swift
git commit -m "feat(core): MotionRecording protokolü ve SessionRecorder durum makinesi"
```

---

## Tamamlanma kriteri (Plan 1)

- `swift test --package-path SmokeTrackerCore` tüm testlerle geçer.
- Çekirdek pakette UI/CoreMotion/WatchConnectivity/SwiftData bağımlılığı yoktur.
- Plan 2'nin ihtiyaç duyacağı tüm soyutlamalar (`EventStoring`, `DateProviding`, `MotionRecording`) ve mantık birimleri (`StatsEngine`, `SyncCoordinator`, `QuickLogManager`, `SessionRecorder`) hazır ve test edilmiştir.

## Sonraki adımlar

- **Plan 2** yazılacak: Xcode iOS+watchOS hedefleri, `SwiftData` tabanlı `EventStore` (`EventStoring` gerçeklemesi), `WatchConnectivity` senkronu, temel SwiftUI ekranları (bugünkü sayı + büyük "+1" butonu + günlük/haftalık istatistik).
- **Plan 3** yazılacak: Complication, `CMSensorRecorder` ile `MotionRecording` gerçeklemesi, `TrainingDataArchive`, onboarding/izinler.
