# SmokeTracker App Kabuğu (Watch + iPhone, Kalıcılık & Senkron) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Çalışan bir Watch + iPhone uygulaması: watch'ta tek dokunuşla +1 kaydı yapılır, yerelde kalıcı olur ve WatchConnectivity ile iPhone'a senkronlanır; iPhone SwiftData'da ana depoyu tutar ve günlük/haftalık sayıları + geçmişi gösterir.

**Architecture:** Test edilebilir kalıcılık ve senkron mantığı yeni bir SPM paketinde (`SmokeTrackerData`) toplanır ve `swift test` ile doğrulanır: SwiftData tabanlı `SwiftDataEventStore`, dosya tabanlı `FileEventStore` (watch yerel kuyruğu) ve `SyncMessageCodec` (WCSession yükü kodlayıcı) — hepsi Plan 1'in `EventStoring`/`SmokingEvent` soyutlamalarını kullanır. Xcode iOS + watchOS app hedefleri (XcodeGen ile üretilir) bu paketleri + `SmokeTrackerCore`'u tüketir; SwiftUI ekranları ve WCSession bağlama kodu ince tutulur ve `xcodebuild` + simülatör ile doğrulanır.

**Tech Stack:** Swift 6.3 (tools-version 6.0), SwiftPM, Swift Testing, SwiftData, SwiftUI, WatchConnectivity, XcodeGen. Xcode 26.5 (iOS/watchOS 26.5 SDK).

---

## Ön koşullar

- **XcodeGen gerekli** (kurulu değil). Kurulum: `brew install xcodegen`. Bu, kullanıcının makinesine bir geliştirme aracı kurar — yürütmeye başlamadan önce onay alın.
- Plan 1 (`SmokeTrackerCore`) `main`'de tamam olmalı (bu plan onun protokollerine ve modeline dayanır).
- Çalışma dizini: depo kökü `/Users/batu/projeler/smoke-tracker`. Tüm komutlar kökten çalışır.
- `swift test` çağrıları, çevre sanal kutusu (sandbox) derleme önbelleğini engellerse yazılabilir önbellek + SwiftPM `--disable-sandbox` ile çalıştırılmalıdır; **kodun kendisi değişmez**.

## Kapsam (YAGNI)

Bu plan SADECE manuel +1 akışını, kalıcılığı, watch→iPhone senkronunu ve temel istatistik/geçmiş ekranlarını kapsar. **Kapsam dışı (Plan 3):** complication, `CMSensorRecorder` ile gerçek `MotionRecording`, sensörlü seans UI'ı, eğitim verisi arşivi, onboarding/izinler. Manuel +1 hiçbir özel izin gerektirmediği için bu plan izin akışları olmadan tam çalışır.

---

## Dosya yapısı (Plan 2)

```
smoke-tracker/
  SmokeTrackerCore/                      # mevcut (Plan 1)
  SmokeTrackerData/                      # YENİ SPM paketi
    Package.swift
    Sources/SmokeTrackerData/
      SmokingEventRecord.swift           # @Model (SwiftData)
      SwiftDataEventStore.swift          # EventStoring impl + container fabrikası
      FileEventStore.swift               # EventStoring impl (JSON dosya; watch yereli)
      SyncMessageCodec.swift             # [SmokingEvent] <-> Data (WCSession yükü)
    Tests/SmokeTrackerDataTests/
      SwiftDataEventStoreTests.swift
      FileEventStoreTests.swift
      SyncMessageCodecTests.swift
  SmokeTrackerApp/                       # YENİ Xcode projesi (XcodeGen)
    project.yml
    iOS/
      Info.plist
      SmokeTrackerApp.swift              # @main App (iPhone)
      PhoneModel.swift                   # SwiftData + SyncCoordinator + StatsEngine bağlama
      TodayView.swift                    # bugün/hafta sayıları
      HistoryView.swift                  # olay geçmişi listesi
      PhoneSyncReceiver.swift            # WCSession alıcı (watch -> phone)
    Watch/
      Info.plist
      SmokeTrackerWatchApp.swift         # @main App (watch)
      WatchModel.swift                   # FileEventStore + QuickLogManager + sender
      WatchTodayView.swift               # bugün sayısı + büyük +1 butonu
      WatchSyncSender.swift              # WCSession gönderici (phone'a)
```

Her dosya tek sorumluluk taşır. SPM paketi (`SmokeTrackerData`) tüm test edilebilir mantığı barındırır; Xcode hedefleri ince UI/glue katmanıdır.

---

## FAZ A — SmokeTrackerData paketi (tam TDD, `swift test`)

### Task 1: SmokeTrackerData paketini başlat + SwiftDataEventStore

**Files:**
- Create: `SmokeTrackerData/Package.swift`
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/SmokingEventRecord.swift`
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/SwiftDataEventStore.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/SwiftDataEventStoreTests.swift`
- Create: `SmokeTrackerData/.gitignore`

- [ ] **Step 1: Package.swift ve .gitignore oluştur**

`SmokeTrackerData/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SmokeTrackerData",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SmokeTrackerData", targets: ["SmokeTrackerData"]),
    ],
    dependencies: [
        .package(path: "../SmokeTrackerCore"),
    ],
    targets: [
        .target(
            name: "SmokeTrackerData",
            dependencies: [
                .product(name: "SmokeTrackerCore", package: "SmokeTrackerCore")
            ]
        ),
        .testTarget(
            name: "SmokeTrackerDataTests",
            dependencies: ["SmokeTrackerData"]
        ),
    ]
)
```

`SmokeTrackerData/.gitignore`:

```
.build/
.swiftpm/
```

- [ ] **Step 2: Failing test'i yaz**

`SmokeTrackerData/Tests/SmokeTrackerDataTests/SwiftDataEventStoreTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct SwiftDataEventStoreTests {
    private func makeStore() throws -> SwiftDataEventStore {
        let container = try EventStoreFactory.makeInMemoryContainer()
        return SwiftDataEventStore(context: ModelContext(container))
    }

    private func event(_ id: UUID = UUID(), _ ts: Date = Date(timeIntervalSince1970: 1_700_000_000), _ source: EventSource = .tap) -> SmokingEvent {
        SmokingEvent(id: id, timestamp: ts, source: source)
    }

    @Test func addThenAllEventsReturnsIt() throws {
        let store = try makeStore()
        let e = event()
        store.add(e)
        let all = store.allEvents()
        #expect(all.count == 1)
        #expect(all.first == e)
    }

    @Test func containsReflectsAddedEvent() throws {
        let store = try makeStore()
        let id = UUID()
        #expect(store.contains(id: id) == false)
        store.add(event(id))
        #expect(store.contains(id: id) == true)
    }

    @Test func duplicateIdIsNotStoredTwice() throws {
        let store = try makeStore()
        let id = UUID()
        store.add(event(id, Date(timeIntervalSince1970: 1)))
        store.add(event(id, Date(timeIntervalSince1970: 2)))
        #expect(store.allEvents().count == 1)
    }

    @Test func eventsAreReturnedSortedByTimestamp() throws {
        let store = try makeStore()
        store.add(event(UUID(), Date(timeIntervalSince1970: 300)))
        store.add(event(UUID(), Date(timeIntervalSince1970: 100)))
        store.add(event(UUID(), Date(timeIntervalSince1970: 200)))
        let times = store.allEvents().map { $0.timestamp.timeIntervalSince1970 }
        #expect(times == [100, 200, 300])
    }
}
```

- [ ] **Step 3: Testi çalıştır, başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerData --filter SwiftDataEventStoreTests`
Expected: FAIL — derleme hatası `cannot find 'EventStoreFactory'` / `'SwiftDataEventStore' in scope`.

- [ ] **Step 4: SmokingEventRecord modelini yaz**

`SmokeTrackerData/Sources/SmokeTrackerData/SmokingEventRecord.swift`:

```swift
import Foundation
import SwiftData

/// SmokingEvent'in SwiftData kalıcı temsili.
@Model
public final class SmokingEventRecord {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var sourceRaw: String

    public init(id: UUID, timestamp: Date, sourceRaw: String) {
        self.id = id
        self.timestamp = timestamp
        self.sourceRaw = sourceRaw
    }
}
```

- [ ] **Step 5: SwiftDataEventStore'u yaz**

`SmokeTrackerData/Sources/SmokeTrackerData/SwiftDataEventStore.swift`:

```swift
import Foundation
import SwiftData
import SmokeTrackerCore

/// ModelContainer üreten fabrika.
public enum EventStoreFactory {
    /// Testler ve geçici kullanım için bellek-içi konteyner.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SmokingEventRecord.self, configurations: config)
    }

    /// Uygulama için diske kalıcı konteyner.
    public static func makePersistentContainer() throws -> ModelContainer {
        try ModelContainer(for: SmokingEventRecord.self)
    }
}

/// SwiftData tabanlı EventStoring gerçeklemesi (iPhone tarafı ana depo).
///
/// NOT: `ModelContext` Sendable değildir; bu nesne tek bir iş parçacığından/
/// aktörden (uygulamada MainActor) kullanılmalıdır. Bu yüzden bu tip
/// `@MainActor` ile işaretlenmez (nonisolated `EventStoring` gereksinimlerini
/// karşılayabilmek için) ama eşzamanlı erişimden kaçınmak çağıranın görevidir.
public final class SwiftDataEventStore: EventStoring {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func allEvents() -> [SmokingEvent] {
        let descriptor = FetchDescriptor<SmokingEventRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { record in
            guard let source = EventSource(rawValue: record.sourceRaw) else { return nil }
            return SmokingEvent(id: record.id, timestamp: record.timestamp, source: source)
        }
    }

    public func add(_ event: SmokingEvent) {
        guard !contains(id: event.id) else { return }
        let record = SmokingEventRecord(
            id: event.id,
            timestamp: event.timestamp,
            sourceRaw: event.source.rawValue
        )
        context.insert(record)
        try? context.save()
    }

    public func contains(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<SmokingEventRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }
}
```

- [ ] **Step 6: Testi çalıştır, geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerData --filter SwiftDataEventStoreTests`
Expected: PASS — `4 tests passed`.

- [ ] **Step 7: Commit**

```bash
git add SmokeTrackerData/Package.swift SmokeTrackerData/.gitignore SmokeTrackerData/Sources/SmokeTrackerData/SmokingEventRecord.swift SmokeTrackerData/Sources/SmokeTrackerData/SwiftDataEventStore.swift SmokeTrackerData/Tests/SmokeTrackerDataTests/SwiftDataEventStoreTests.swift
git commit -m "feat(data): SwiftData tabanlı SwiftDataEventStore + paket"
```

---

### Task 2: FileEventStore (watch yerel kuyruğu)

**Files:**
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/FileEventStore.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/FileEventStoreTests.swift`

- [ ] **Step 1: Failing test'i yaz**

`SmokeTrackerData/Tests/SmokeTrackerDataTests/FileEventStoreTests.swift`:

```swift
import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct FileEventStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("fes-\(UUID().uuidString).json")
    }

    private func event(_ id: UUID = UUID(), _ t: Double = 100) -> SmokingEvent {
        SmokingEvent(id: id, timestamp: Date(timeIntervalSince1970: t), source: .tap)
    }

    @Test func addStoresEventInMemory() {
        let store = FileEventStore(url: tempURL())
        let e = event()
        store.add(e)
        #expect(store.allEvents() == [e])
    }

    @Test func persistsAcrossInstancesAtSameURL() {
        let url = tempURL()
        let e = event()
        let first = FileEventStore(url: url)
        first.add(e)

        let second = FileEventStore(url: url)
        #expect(second.allEvents() == [e])
    }

    @Test func deduplicatesById() {
        let url = tempURL()
        let id = UUID()
        let store = FileEventStore(url: url)
        store.add(event(id, 1))
        store.add(event(id, 2))
        #expect(store.allEvents().count == 1)
    }

    @Test func emptyWhenFileMissing() {
        let store = FileEventStore(url: tempURL())
        #expect(store.allEvents().isEmpty)
        #expect(store.contains(id: UUID()) == false)
    }
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerData --filter FileEventStoreTests`
Expected: FAIL — derleme hatası `cannot find 'FileEventStore' in scope`.

- [ ] **Step 3: FileEventStore'u yaz**

`SmokeTrackerData/Sources/SmokeTrackerData/FileEventStore.swift`:

```swift
import Foundation
import SmokeTrackerCore

/// JSON dosyasına kalıcı, basit EventStoring gerçeklemesi.
/// Watch tarafında, senkronlanana kadar olayları yerelde tutmak için kullanılır.
///
/// NOT: SwiftDataEventStore gibi, tek bir iş parçacığından/aktörden
/// (uygulamada MainActor) kullanılmalıdır.
public final class FileEventStore: EventStoring {
    private let url: URL
    private var events: [SmokingEvent]

    public init(url: URL) {
        self.url = url
        self.events = Self.load(from: url)
    }

    public func allEvents() -> [SmokingEvent] { events }

    public func add(_ event: SmokingEvent) {
        guard !contains(id: event.id) else { return }
        events.append(event)
        persist()
    }

    public func contains(id: UUID) -> Bool {
        events.contains { $0.id == id }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func load(from url: URL) -> [SmokingEvent] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SmokingEvent].self, from: data) else {
            return []
        }
        return decoded
    }
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerData --filter FileEventStoreTests`
Expected: PASS — `4 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerData/Sources/SmokeTrackerData/FileEventStore.swift SmokeTrackerData/Tests/SmokeTrackerDataTests/FileEventStoreTests.swift
git commit -m "feat(data): FileEventStore (watch yerel JSON kuyruğu)"
```

---

### Task 3: SyncMessageCodec (WCSession yükü)

**Files:**
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/SyncMessageCodec.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/SyncMessageCodecTests.swift`

- [ ] **Step 1: Failing test'i yaz**

`SmokeTrackerData/Tests/SmokeTrackerDataTests/SyncMessageCodecTests.swift`:

```swift
import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct SyncMessageCodecTests {
    @Test func roundTripPreservesEvents() throws {
        let events = [
            SmokingEvent(id: UUID(), timestamp: Date(timeIntervalSince1970: 100), source: .tap),
            SmokingEvent(id: UUID(), timestamp: Date(timeIntervalSince1970: 200), source: .session),
        ]
        let data = try SyncMessageCodec.encode(events)
        let decoded = try SyncMessageCodec.decode(data)
        #expect(decoded == events)
    }

    @Test func decodingGarbageThrows() {
        let garbage = Data([0x00, 0x01, 0x02])
        #expect(throws: (any Error).self) {
            _ = try SyncMessageCodec.decode(garbage)
        }
    }

    @Test func encodesVersionField() throws {
        let data = try SyncMessageCodec.encode([])
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect((object?["version"] as? Int) == 1)
    }
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu doğrula**

Run: `swift test --package-path SmokeTrackerData --filter SyncMessageCodecTests`
Expected: FAIL — derleme hatası `cannot find 'SyncMessageCodec' in scope`.

- [ ] **Step 3: SyncMessageCodec'i yaz**

`SmokeTrackerData/Sources/SmokeTrackerData/SyncMessageCodec.swift`:

```swift
import Foundation
import SmokeTrackerCore

/// WCSession üzerinden taşınan sürümlü senkron mesajı.
public struct SyncMessage: Codable, Sendable {
    public let version: Int
    public let events: [SmokingEvent]

    public init(version: Int = 1, events: [SmokingEvent]) {
        self.version = version
        self.events = events
    }
}

/// Olay dizisini WCSession yükü (Data) ile kodlar/çözer.
public enum SyncMessageCodec {
    public static func encode(_ events: [SmokingEvent]) throws -> Data {
        try JSONEncoder().encode(SyncMessage(events: events))
    }

    public static func decode(_ data: Data) throws -> [SmokingEvent] {
        try JSONDecoder().decode(SyncMessage.self, from: data).events
    }
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini doğrula**

Run: `swift test --package-path SmokeTrackerData --filter SyncMessageCodecTests`
Expected: PASS — `3 tests passed`.

- [ ] **Step 5: Tüm Data paketini çalıştır (regresyon)**

Run: `swift test --package-path SmokeTrackerData`
Expected: PASS — tüm testler (11 test) geçer.

- [ ] **Step 6: Commit**

```bash
git add SmokeTrackerData/Sources/SmokeTrackerData/SyncMessageCodec.swift SmokeTrackerData/Tests/SmokeTrackerDataTests/SyncMessageCodecTests.swift
git commit -m "feat(data): SyncMessageCodec (WCSession yük kodlayıcı)"
```

---

## FAZ B — Xcode projesi iskeleti (XcodeGen, `xcodebuild` ile doğrulanır)

> Bu fazdan itibaren doğrulama birim testi değil; **`xcodebuild build` derleme kapısı** + simülatör manuel testidir. Info.plist/build ayarları gerekirse yürütme sırasında derleyiciye karşı düzeltilir.

### Task 4: XcodeGen project.yml + minimal iki app hedefi (derlenir)

**Files:**
- Create: `SmokeTrackerApp/project.yml`
- Create: `SmokeTrackerApp/iOS/Info.plist`
- Create: `SmokeTrackerApp/iOS/SmokeTrackerApp.swift`
- Create: `SmokeTrackerApp/Watch/Info.plist`
- Create: `SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift`
- Modify: `.gitignore` (kökte, üretilen .xcodeproj'u yoksay)

- [ ] **Step 1: XcodeGen kurulu mu doğrula (ön koşul)**

Run: `which xcodegen || brew install xcodegen`
Expected: `xcodegen` yolu yazdırılır (yoksa kurulur — kullanıcı onayı gerekir).

- [ ] **Step 2: project.yml oluştur**

`SmokeTrackerApp/project.yml`:

```yaml
name: SmokeTracker
options:
  bundleIdPrefix: com.oero.smoketracker
  deploymentTarget:
    iOS: "17.0"
    watchOS: "10.0"
  createIntermediateGroups: true
packages:
  SmokeTrackerCore:
    path: ../SmokeTrackerCore
  SmokeTrackerData:
    path: ../SmokeTrackerData
settings:
  base:
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    SWIFT_VERSION: "6.0"
    GENERATE_INFOPLIST_FILE: "NO"
targets:
  SmokeTracker:
    type: application
    platform: iOS
    sources:
      - path: iOS
    dependencies:
      - package: SmokeTrackerCore
      - package: SmokeTrackerData
      - target: SmokeTrackerWatch
        embed: true
    settings:
      base:
        INFOPLIST_FILE: iOS/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.oero.smoketracker
        TARGETED_DEVICE_FAMILY: "1"
  SmokeTrackerWatch:
    type: application
    platform: watchOS
    sources:
      - path: Watch
    dependencies:
      - package: SmokeTrackerCore
      - package: SmokeTrackerData
    settings:
      base:
        INFOPLIST_FILE: Watch/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.oero.smoketracker.watchkitapp
        TARGETED_DEVICE_FAMILY: "4"
```

- [ ] **Step 3: iOS Info.plist oluştur**

`SmokeTrackerApp/iOS/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
    </dict>
</dict>
</plist>
```

- [ ] **Step 4: iOS @main App oluştur (minimal)**

`SmokeTrackerApp/iOS/SmokeTrackerApp.swift`:

```swift
import SwiftUI

@main
struct SmokeTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("SmokeTracker")
        }
    }
}
```

- [ ] **Step 5: Watch Info.plist oluştur**

`SmokeTrackerApp/Watch/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>WKApplication</key>
    <true/>
    <key>WKCompanionAppBundleIdentifier</key>
    <string>com.oero.smoketracker</string>
</dict>
</plist>
```

- [ ] **Step 6: Watch @main App oluştur (minimal)**

`SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift`:

```swift
import SwiftUI

@main
struct SmokeTrackerWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("SmokeTracker")
        }
    }
}
```

- [ ] **Step 7: Kök .gitignore'a üretilen proje + DerivedData ekle**

`/Users/batu/projeler/smoke-tracker/.gitignore` (yoksa oluştur, varsa ekle):

```
SmokeTrackerApp/*.xcodeproj
.DS_Store
DerivedData/
```

- [ ] **Step 8: Projeyi üret ve her iki hedefi derle**

Run:
```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -scheme SmokeTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -scheme SmokeTrackerWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```
Expected: Her iki `xcodebuild` de `** BUILD SUCCEEDED **` ile biter. (iOS şeması, gömülü watch hedefini de derler.) Derleme ayar/Info.plist hatası çıkarsa düzelt ve tekrar dene; kod mantığı bu adımda değişmez.

- [ ] **Step 9: Commit**

```bash
git add SmokeTrackerApp/project.yml SmokeTrackerApp/iOS SmokeTrackerApp/Watch .gitignore
git commit -m "feat(app): XcodeGen projesi + iskelet iOS/watchOS app hedefleri"
```

---

## FAZ C — watchOS UI + yerel kayıt

### Task 5: Watch +1 akışı (FileEventStore + QuickLogManager + ekran)

**Files:**
- Create: `SmokeTrackerApp/Watch/WatchSyncSender.swift`
- Create: `SmokeTrackerApp/Watch/WatchModel.swift`
- Create: `SmokeTrackerApp/Watch/WatchTodayView.swift`
- Modify: `SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift`

- [ ] **Step 1: WatchSyncSender'ı yaz (şimdilik phone'a gönderir)**

`SmokeTrackerApp/Watch/WatchSyncSender.swift`:

```swift
import Foundation
import WatchConnectivity
import SmokeTrackerCore
import SmokeTrackerData

/// Yeni olayları WCSession ile iPhone'a güvenilir biçimde aktarır.
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

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
```

- [ ] **Step 2: WatchModel'i yaz**

`SmokeTrackerApp/Watch/WatchModel.swift`:

```swift
import Foundation
import Observation
import SmokeTrackerCore
import SmokeTrackerData

/// Watch tarafı durum: yerel kayıt + bugünkü sayı + gönderim.
@MainActor
@Observable
final class WatchModel {
    private let store: FileEventStore
    private let quickLog: QuickLogManager
    private let sender: WatchSyncSender
    private let stats = StatsEngine(calendar: .current)

    var todayCount: Int = 0

    init() {
        let url = URL.documentsDirectory.appendingPathComponent("watch-events.json")
        let store = FileEventStore(url: url)
        self.store = store
        self.quickLog = QuickLogManager(store: store, dateProvider: SystemDateProvider())
        self.sender = WatchSyncSender()
        refresh()
    }

    /// +1: yerelde kaydet, iPhone'a gönder, sayıyı güncelle.
    func logOne() {
        let event = quickLog.logOne()
        sender.send(event)
        refresh()
    }

    private func refresh() {
        todayCount = stats.count(on: Date(), events: store.allEvents())
    }
}
```

- [ ] **Step 3: WatchTodayView'ı yaz**

`SmokeTrackerApp/Watch/WatchTodayView.swift`:

```swift
import SwiftUI

struct WatchTodayView: View {
    let model: WatchModel

    var body: some View {
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
        }
        .padding()
    }
}
```

- [ ] **Step 4: Watch @main App'i WatchModel'e bağla**

`SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift` (tüm dosyayı değiştir):

```swift
import SwiftUI

@main
struct SmokeTrackerWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchTodayView(model: model)
        }
    }
}
```

- [ ] **Step 5: Üret ve watch hedefini derle**

Run:
```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -scheme SmokeTrackerWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manuel doğrulama (watch simülatörü)**

Watch uygulamasını Apple Watch Series 11 simülatöründe çalıştır. Beklenen: büyük sayı "0" + "Sigara" butonu. Butona bas → sayı 1, 2, 3... artar. Uygulamayı kapatıp aç → sayı korunur (FileEventStore kalıcılığı).

- [ ] **Step 7: Commit**

```bash
git add SmokeTrackerApp/Watch
git commit -m "feat(watch): yerel +1 kaydı, bugünkü sayı ekranı ve gönderim"
```

---

## FAZ D — iPhone UI + istatistik

### Task 6: iPhone ana depo + bugün/hafta + geçmiş

**Files:**
- Create: `SmokeTrackerApp/iOS/PhoneModel.swift`
- Create: `SmokeTrackerApp/iOS/TodayView.swift`
- Create: `SmokeTrackerApp/iOS/HistoryView.swift`
- Modify: `SmokeTrackerApp/iOS/SmokeTrackerApp.swift`

> Not: `PhoneSyncReceiver` Task 7'de eklenecek. Bu task'ta PhoneModel önce yalnızca yerel SwiftData deposunu okur/yazar; senkron alımı Task 7'de bağlanır.

- [ ] **Step 1: PhoneModel'i yaz (senkron alıcı olmadan)**

`SmokeTrackerApp/iOS/PhoneModel.swift`:

```swift
import Foundation
import Observation
import SwiftData
import SmokeTrackerCore
import SmokeTrackerData

/// iPhone tarafı durum: SwiftData ana deposu + istatistik.
@MainActor
@Observable
final class PhoneModel {
    let store: SwiftDataEventStore
    let coordinator: SyncCoordinator
    private let stats = StatsEngine(calendar: .current)

    var todayCount: Int = 0
    var weekCount: Int = 0
    var history: [SmokingEvent] = []

    init() {
        let container = try! EventStoreFactory.makePersistentContainer()
        let store = SwiftDataEventStore(context: ModelContext(container))
        self.store = store
        self.coordinator = SyncCoordinator(store: store)
        refresh()
    }

    func refresh() {
        let all = store.allEvents()
        todayCount = stats.count(on: Date(), events: all)
        weekCount = stats.countInWeek(containing: Date(), events: all)
        history = all.sorted { $0.timestamp > $1.timestamp }
    }
}
```

- [ ] **Step 2: TodayView'ı yaz**

`SmokeTrackerApp/iOS/TodayView.swift`:

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
            }
            .padding()
            .navigationTitle("Sigara Takip")
        }
    }
}
```

- [ ] **Step 3: HistoryView'ı yaz**

`SmokeTrackerApp/iOS/HistoryView.swift`:

```swift
import SwiftUI
import SmokeTrackerCore

struct HistoryView: View {
    let events: [SmokingEvent]

    var body: some View {
        List(events) { event in
            HStack {
                Text(event.timestamp, format: .dateTime.day().month().year())
                Spacer()
                Text(event.timestamp, format: .dateTime.hour().minute())
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Geçmiş")
    }
}
```

- [ ] **Step 4: iOS @main App'i PhoneModel'e bağla**

`SmokeTrackerApp/iOS/SmokeTrackerApp.swift` (tüm dosyayı değiştir):

```swift
import SwiftUI

@main
struct SmokeTrackerApp: App {
    @State private var model = PhoneModel()

    var body: some Scene {
        WindowGroup {
            TodayView(model: model)
        }
    }
}
```

- [ ] **Step 5: Üret ve iOS hedefini derle**

Run:
```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -scheme SmokeTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manuel doğrulama (iPhone simülatörü)**

iPhone 17 Pro simülatöründe uygulamayı çalıştır. Beklenen: "Bugün 0", "Bu hafta: 0", "Geçmiş" bağlantısı. (Senkron Task 7'de gelecek; şimdilik veri yok.)

- [ ] **Step 7: Commit**

```bash
git add SmokeTrackerApp/iOS
git commit -m "feat(ios): SwiftData ana depo + bugün/hafta sayıları + geçmiş ekranı"
```

---

## FAZ E — WatchConnectivity senkronu (uçtan uca)

### Task 7: iPhone alıcısı ve watch→phone senkronu

**Files:**
- Create: `SmokeTrackerApp/iOS/PhoneSyncReceiver.swift`
- Modify: `SmokeTrackerApp/iOS/PhoneModel.swift`

- [ ] **Step 1: PhoneSyncReceiver'ı yaz**

`SmokeTrackerApp/iOS/PhoneSyncReceiver.swift`:

```swift
import Foundation
import WatchConnectivity
import SmokeTrackerCore
import SmokeTrackerData

/// Watch'tan gelen olayları alır ve SyncCoordinator ile ana depoya işler.
/// WCSession delegate çağrıları arka planda gelir; deposu MainActor'da olduğu
/// için işleme MainActor'a taşınır.
@MainActor
final class PhoneSyncReceiver: NSObject, WCSessionDelegate {
    private let coordinator: SyncCoordinator
    private let onChange: () -> Void

    init(coordinator: SyncCoordinator, onChange: @escaping () -> Void) {
        self.coordinator = coordinator
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

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
```

- [ ] **Step 2: PhoneModel'e alıcıyı bağla**

`SmokeTrackerApp/iOS/PhoneModel.swift` içinde, `coordinator` özelliğinin hemen ardına bir alıcı özelliği ve `init` sonunda kurulumunu ekle. Değiştirilmiş dosyanın tamamı:

```swift
import Foundation
import Observation
import SwiftData
import SmokeTrackerCore
import SmokeTrackerData

/// iPhone tarafı durum: SwiftData ana deposu + istatistik + senkron alıcı.
@MainActor
@Observable
final class PhoneModel {
    let store: SwiftDataEventStore
    let coordinator: SyncCoordinator
    private let stats = StatsEngine(calendar: .current)
    private var receiver: PhoneSyncReceiver?

    var todayCount: Int = 0
    var weekCount: Int = 0
    var history: [SmokingEvent] = []

    init() {
        let container = try! EventStoreFactory.makePersistentContainer()
        let store = SwiftDataEventStore(context: ModelContext(container))
        self.store = store
        self.coordinator = SyncCoordinator(store: store)
        refresh()
        self.receiver = PhoneSyncReceiver(coordinator: coordinator) { [weak self] in
            self?.refresh()
        }
    }

    func refresh() {
        let all = store.allEvents()
        todayCount = stats.count(on: Date(), events: all)
        weekCount = stats.countInWeek(containing: Date(), events: all)
        history = all.sorted { $0.timestamp > $1.timestamp }
    }
}
```

- [ ] **Step 3: Üret ve iOS hedefini derle**

Run:
```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -scheme SmokeTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Uçtan uca manuel doğrulama (eşli simülatörler)**

Xcode'da iPhone 17 Pro + eşli Apple Watch Series 11 simülatörlerini başlat. Her iki uygulamayı da çalıştır. Watch'ta "Sigara" butonuna birkaç kez bas. Beklenen: kısa bir gecikmenin ardından iPhone'daki "Bugün" sayısı artar ve "Geçmiş" listesinde olaylar görünür. (Not: `transferUserInfo` teslimi simülatörde birkaç saniye gecikebilir; WCSession eşleşmesi için her iki simülatör de açık olmalı.)

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerApp/iOS
git commit -m "feat(sync): WatchConnectivity ile watch->iPhone olay senkronu"
```

---

## Tamamlanma kriteri (Plan 2)

- `swift test --package-path SmokeTrackerData` tüm testlerle (11 test) geçer.
- `xcodebuild ... -scheme SmokeTracker` ve `-scheme SmokeTrackerWatch` `BUILD SUCCEEDED` verir.
- Manuel: watch'ta +1 → yerelde kalıcı + iPhone'da sayı/geçmiş güncellenir.
- Çekirdek mantık (`EventStoring`, `StatsEngine`, `SyncCoordinator`, `QuickLogManager`) test edilmiş paketlerden tüketilir; Xcode hedeflerinde iş mantığı tekrarı yoktur.

## Sonraki adımlar

- **Plan 3:** Complication (kadrandan tek dokunuş), `CMSensorRecorder` ile gerçek `MotionRecording` gerçeklemesi ve sensörlü seans UI'ı (`SessionRecorder`'ı bağlar), `TrainingDataArchive` (ham seans verisi, izinle), onboarding + Motion & Fitness izinleri, gizlilik ekranı. Ayrıca phone→watch geri-senkron ve günlük sıfırlama/gün sınırı kenar durumlarının manuel doğrulaması.
