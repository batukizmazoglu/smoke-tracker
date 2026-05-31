# Complication — Kadrandan Tek Dokunuş +1 (Plan 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apple Watch kadranına, bugünkü sigara sayısını gösteren ve **tek dokunuşla +1** işleyen bir complication (WidgetKit accessory widget) ekle. Bu, spec'in birincil giriş noktasını tamamlar.

**Architecture:** Complication, watch app'e gömülü ayrı bir **WidgetKit extension** hedefidir. Bugünkü sayıyı gösterebilmesi için widget ile watch app aynı olay dosyasını bir **App Group** paylaşımlı konteynerinde okur (`SharedContainer`). Dokunma, `widgetURL` ile `smoketracker://log` derin bağlantısını watch app'e iletir; app `onOpenURL` ile (kısa bir `TapThrottle` arkasında) +1 işler ve `WidgetCenter` ile complication'ı tazeler. Test edilebilir öz (`TapThrottle`, `SharedContainer` fallback) SPM paketlerine TDD ile yazılır; widget + hedef + derin bağlantı app katmanında yalnızca **derleme** ile doğrulanır.

**Tech Stack:** WidgetKit (accessory families), App Intents yok (derin bağlantı tercih edildi), SwiftUI, App Group (`group.com.oero.smoketracker`) + entitlements, WatchConnectivity (mevcut), XcodeGen (app-extension hedefi), Swift Testing.

---

## Ortam Notu (kritik)

Bu Mac'te simülatör/cihaz çalıştırılamıyor (CoreSimulator uyumsuzluğu + yalnızca 26.4 runtime). Doğrulama:
- Paketler: `TMPDIR=/private/tmp swift test --package-path <SmokeTrackerCore|SmokeTrackerData>` (TMPDIR şart; SwiftPM cache sandbox'ı için).
- App + gömülü watch + gömülü widget derlemesi:

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker \
  -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```

`-sdk` override'ı **KULLANMA**. `SmokeTracker` (iOS) hedefini derlemek, gömülü `SmokeTrackerWatch`'u ve onun gömülü `SmokeTrackerWatchWidget`'ını da kendi watchOS SDK'larıyla derler (`embed: true` zinciri). Entitlements (App Group) yalnızca imzalama/çalışma-zamanında geçerlidir; `CODE_SIGNING_ALLOWED=NO` ile derleme bunları yok sayar — bu yüzden `SharedContainer` App Group konteyneri yoksa Documents'a düşer (graceful). Complication'ın canlı verisi ve derin bağlantı yalnızca gerçek cihazda/imzalı çalıştırmada uçtan uca doğrulanabilir.

**Not:** `SmokeTrackerApp/project.yml` ve `.entitlements` dosyaları git'te İZLENİR (commit edilir). `.xcodeproj` ise gitignore'da (`SmokeTrackerApp/*.xcodeproj`) — üretilir, commit edilmez.

---

## Kapsam (Plan 4) ve kapsam dışı (Plan 5)

**Plan 4 (bu plan):** Complication (accessory widget), App Group paylaşımlı olay deposu, kadrandan tek dokunuş → +1 (derin bağlantı + throttle), gün dönümünde widget tazeleme.

**Plan 5 (sonraki):** Tam onboarding akışı (ilk açılış), ayrı gizlilik/izin ekranı, proaktif Motion & Fitness izni, cihazlar-arası onay (consent) senkronu (iPhone onboarding onayını WCSession applicationContext ile watch'a taşıma; Plan 3'teki seans-içi toggle'ı onboarding onayıyla zenginleştirme).

**Bilinçli kapsam dışı:** App Intents ile uygulamayı açmadan +1 (widget sürecinden App Group'a yazma gerektirir; derin bağlantı daha basit ve spec'in "uygulama açılır" akışına uygun). HKWorkoutSession (Faz 2). iPhone tarafı complication/widget (yalnızca watch kadranı hedefleniyor).

---

## File Structure

**Yeni — test edilebilir paket katmanı:**
- `SmokeTrackerCore/Sources/SmokeTrackerCore/TapThrottle.swift` — kısa aralıklı tekrar dokunuşları eleyen kısıtlayıcı.
- `SmokeTrackerData/Sources/SmokeTrackerData/SharedContainer.swift` — App Group paylaşımlı olay dosyası konumu (+ Documents fallback).
- Testler: `SmokeTrackerCoreTests/TapThrottleTests.swift`, `SmokeTrackerDataTests/SharedContainerTests.swift`.

**Yeni — app/widget katmanı (derleme ile doğrulanır):**
- `SmokeTrackerApp/WatchWidget/SmokeTrackerWatchWidget.swift` — WidgetBundle + Widget + TimelineProvider + view.
- `SmokeTrackerApp/WatchWidget/Info.plist` — widgetkit-extension.
- `SmokeTrackerApp/WatchWidget/SmokeTrackerWatchWidget.entitlements` — App Group.
- `SmokeTrackerApp/Watch/SmokeTrackerWatch.entitlements` — App Group.

**Değişen:**
- `SmokeTrackerApp/project.yml` — widget extension hedefi + entitlements + watch app'in widget'ı gömmesi.
- `SmokeTrackerApp/Watch/Info.plist` — `CFBundleURLTypes` (smoketracker şeması).
- `SmokeTrackerApp/Watch/WatchModel.swift` — paylaşımlı konteyner URL'i, `TapThrottle`, `WidgetCenter` tazeleme, `logFromComplication()`.
- `SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift` — `onOpenURL` derin bağlantı.

---

## Task 1: TapThrottle (Core, TDD)

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/TapThrottle.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/TapThrottleTests.swift`

- [ ] **Step 1: Failing test yaz**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/TapThrottleTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerCore

@Suite struct TapThrottleTests {
    @Test func firstTapIsAccepted() {
        let throttle = TapThrottle(minInterval: 2)
        #expect(throttle.accept(at: Date(timeIntervalSince1970: 100)) == true)
    }

    @Test func secondTapWithinIntervalIsRejected() {
        let throttle = TapThrottle(minInterval: 2)
        _ = throttle.accept(at: Date(timeIntervalSince1970: 100))
        #expect(throttle.accept(at: Date(timeIntervalSince1970: 101)) == false)
    }

    @Test func tapAtIntervalBoundaryIsAccepted() {
        // Tam minInterval (2 sn) sonrası kabul edilir; reddetme yarı-açık (< minInterval).
        let throttle = TapThrottle(minInterval: 2)
        _ = throttle.accept(at: Date(timeIntervalSince1970: 100))
        #expect(throttle.accept(at: Date(timeIntervalSince1970: 102)) == true)
    }
}
```

- [ ] **Step 2: RED doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore --filter TapThrottleTests`
Expected: FAIL — `cannot find 'TapThrottle' in scope`.

- [ ] **Step 3: Implementasyon yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/TapThrottle.swift`:

```swift
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
```

- [ ] **Step 4: GREEN doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore --filter TapThrottleTests`
Expected: PASS (3 test).

- [ ] **Step 5: Regresyon + commit**

```bash
TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore
git add SmokeTrackerCore/Sources/SmokeTrackerCore/TapThrottle.swift \
        SmokeTrackerCore/Tests/SmokeTrackerCoreTests/TapThrottleTests.swift
git commit -m "feat(core): TapThrottle (complication tek-dokunuş tekrar koruması)"
```

Expected: Tüm Core testleri PASS (24).

---

## Task 2: SharedContainer (Data, TDD)

**Files:**
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/SharedContainer.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/SharedContainerTests.swift`

- [ ] **Step 1: Failing test yaz**

`SmokeTrackerData/Tests/SmokeTrackerDataTests/SharedContainerTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct SharedContainerTests {
    @Test func fallsBackToDocumentsWhenAppGroupMissing() {
        // Sağlanmamış bir grup id → containerURL nil → Documents'a düşer,
        // ama dosya adı her durumda korunur.
        let url = SharedContainer.watchEventsURL(appGroup: "group.invalid.\(UUID().uuidString)")
        #expect(url.lastPathComponent == "watch-events.json")
    }
}
```

- [ ] **Step 2: RED doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData --filter SharedContainerTests`
Expected: FAIL — `cannot find 'SharedContainer' in scope`.

- [ ] **Step 3: Implementasyon yaz**

`SmokeTrackerData/Sources/SmokeTrackerData/SharedContainer.swift`:

```swift
import Foundation

/// Watch app'i ile complication uzantısının paylaştığı App Group
/// konteynerindeki olay dosyasının konumunu sağlar. App Group sağlanmamışsa
/// (imzasız geliştirme veya test) Documents'a güvenli biçimde düşer.
public enum SharedContainer {
    /// Watch app'i ve complication'ın paylaştığı App Group kimliği.
    public static let watchAppGroup = "group.com.oero.smoketracker"

    public static func watchEventsURL(appGroup: String = watchAppGroup) -> URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? URL.documentsDirectory
        return base.appendingPathComponent("watch-events.json")
    }
}
```

- [ ] **Step 4: GREEN doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData --filter SharedContainerTests`
Expected: PASS.

- [ ] **Step 5: Regresyon + commit**

```bash
TMPDIR=/private/tmp swift test --package-path SmokeTrackerData
git add SmokeTrackerData/Sources/SmokeTrackerData/SharedContainer.swift \
        SmokeTrackerData/Tests/SmokeTrackerDataTests/SharedContainerTests.swift
git commit -m "feat(data): SharedContainer (App Group paylaşımlı olay dosyası konumu)"
```

Expected: Tüm Data testleri PASS (19).

---

## Task 3: Widget extension hedefi + complication implementasyonu

**Files:**
- Modify: `SmokeTrackerApp/project.yml`
- Create: `SmokeTrackerApp/Watch/SmokeTrackerWatch.entitlements`
- Create: `SmokeTrackerApp/WatchWidget/SmokeTrackerWatchWidget.entitlements`
- Create: `SmokeTrackerApp/WatchWidget/Info.plist`
- Create: `SmokeTrackerApp/WatchWidget/SmokeTrackerWatchWidget.swift`
- Modify: `SmokeTrackerApp/Watch/Info.plist`

- [ ] **Step 1: project.yml'a widget hedefi + entitlements ekle**

`SmokeTrackerApp/project.yml` (tam yeni içerik):

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
      - target: SmokeTrackerWatchWidget
        embed: true
    settings:
      base:
        INFOPLIST_FILE: Watch/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.oero.smoketracker.watchkitapp
        TARGETED_DEVICE_FAMILY: "4"
        CODE_SIGN_ENTITLEMENTS: Watch/SmokeTrackerWatch.entitlements
  SmokeTrackerWatchWidget:
    type: app-extension
    platform: watchOS
    sources:
      - path: WatchWidget
    dependencies:
      - package: SmokeTrackerCore
      - package: SmokeTrackerData
    settings:
      base:
        INFOPLIST_FILE: WatchWidget/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.oero.smoketracker.watchkitapp.widget
        TARGETED_DEVICE_FAMILY: "4"
        CODE_SIGN_ENTITLEMENTS: WatchWidget/SmokeTrackerWatchWidget.entitlements
```

- [ ] **Step 2: Entitlements dosyalarını oluştur**

`SmokeTrackerApp/Watch/SmokeTrackerWatch.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.oero.smoketracker</string>
    </array>
</dict>
</plist>
```

`SmokeTrackerApp/WatchWidget/SmokeTrackerWatchWidget.entitlements` (aynı içerik):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.oero.smoketracker</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Widget Info.plist'i oluştur**

`SmokeTrackerApp/WatchWidget/Info.plist`:

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
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
```

- [ ] **Step 4: Complication kodunu yaz**

`SmokeTrackerApp/WatchWidget/SmokeTrackerWatchWidget.swift`:

```swift
import WidgetKit
import SwiftUI
import SmokeTrackerCore
import SmokeTrackerData

struct CountEntry: TimelineEntry {
    let date: Date
    let count: Int
}

struct CountProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountEntry {
        CountEntry(date: Date(), count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (CountEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountEntry>) -> Void) {
        let entry = currentEntry()
        // Gün dönümünde otomatik yenile (sayaç sıfırlansın).
        let nextMidnight = Calendar.current.nextDate(
            after: entry.date,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? entry.date.addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> CountEntry {
        let store = FileEventStore(url: SharedContainer.watchEventsURL())
        let count = StatsEngine(calendar: .current).count(on: Date(), events: store.allEvents())
        return CountEntry(date: Date(), count: count)
    }
}

struct SmokeTrackerWatchWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountEntry

    var body: some View {
        content
            .widgetURL(URL(string: "smoketracker://log"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label("\(entry.count) sigara", systemImage: "plus.circle")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "plus")
                    .font(.caption2)
                Text("\(entry.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
        case .accessoryCorner:
            Text("\(entry.count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .widgetLabel("sigara")
        default: // .accessoryRectangular
            HStack {
                Image(systemName: "plus.circle.fill")
                VStack(alignment: .leading) {
                    Text("Bugün")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(entry.count) sigara")
                        .font(.headline)
                }
            }
        }
    }
}

struct SmokeTrackerWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SmokeTrackerWatchWidget", provider: CountProvider()) { entry in
            SmokeTrackerWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("Sigara")
        .description("Bugünkü sayı; dokununca +1.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
    }
}

@main
struct SmokeTrackerWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        SmokeTrackerWatchWidget()
    }
}
```

- [ ] **Step 5: Watch Info.plist'e URL şeması ekle**

`SmokeTrackerApp/Watch/Info.plist` içinde `NSMotionUsageDescription` string'inden sonra, `</dict>` kapanışından önce ekle:

```xml
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>smoketracker</string>
            </array>
        </dict>
    </array>
```

- [ ] **Step 6: Üret + derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker \
  -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj 2>&1 | tee /tmp/stb-build.log | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`.
Ayrıca widget hedefinin gerçekten derlendiğini doğrula:

```bash
grep -c "SmokeTrackerWatchWidget" /tmp/stb-build.log
```

Expected: > 0 (widget kaynakları derlendi). Eğer 0 ise, widget gömme zinciri kurulmamış demektir; widget'ı açıkça derle: `xcodebuild ... -target SmokeTrackerWatchWidget ...` (arch'ı xcodebuild seçsin, `-arch` verme).

- [ ] **Step 7: Commit**

```bash
git add SmokeTrackerApp/project.yml \
        SmokeTrackerApp/Watch/SmokeTrackerWatch.entitlements \
        SmokeTrackerApp/WatchWidget/SmokeTrackerWatchWidget.entitlements \
        SmokeTrackerApp/WatchWidget/Info.plist \
        SmokeTrackerApp/WatchWidget/SmokeTrackerWatchWidget.swift \
        SmokeTrackerApp/Watch/Info.plist
git commit -m "feat(watch): kadran complication'ı (WidgetKit) + App Group paylaşımlı sayı"
```

---

## Task 4: Watch app'i complication'a bağla (paylaşımlı depo + derin bağlantı + tazeleme)

**Files:**
- Modify: `SmokeTrackerApp/Watch/WatchModel.swift`
- Modify: `SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift`

- [ ] **Step 1: WatchModel'i güncelle**

`SmokeTrackerApp/Watch/WatchModel.swift` (tam yeni içerik):

```swift
import Foundation
import Observation
import WidgetKit
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
    private let complicationThrottle = TapThrottle(minInterval: 2)

    var todayCount: Int = 0
    var isRecordingSession: Bool = false
    var trainingDataConsent: Bool {
        didSet { consent.trainingDataConsent = trainingDataConsent }
    }

    init() {
        // Olay deposu, complication ile paylaşılan App Group konteynerinde.
        let store = FileEventStore(url: SharedContainer.watchEventsURL())
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

    /// +1: yerelde kaydet, iPhone'a gönder, sayıyı ve complication'ı güncelle.
    func logOne() {
        let event = quickLog.logOne()
        sender.send(event)
        refresh()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Complication'dan gelen +1; çok kısa aralıkta tekrarları eler.
    func logFromComplication() {
        guard complicationThrottle.accept(at: Date()) else { return }
        logOne()
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
        WidgetCenter.shared.reloadAllTimelines()
    }

    func refresh() {
        todayCount = stats.count(on: Date(), events: store.allEvents())
    }
}
```

- [ ] **Step 2: Watch app girişine derin bağlantıyı ekle**

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
                .onOpenURL { url in
                    // Complication "smoketracker://log" ile açtıysa +1 işle.
                    if url.host == "log" { model.logFromComplication() }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }
}
```

- [ ] **Step 3: Üret + derle**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker \
  -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add SmokeTrackerApp/Watch/WatchModel.swift SmokeTrackerApp/Watch/SmokeTrackerWatchApp.swift
git commit -m "feat(watch): paylaşımlı depo + complication derin bağlantısı (+1) + widget tazeleme"
```

---

## Task 5: Uçtan uca derleme doğrulaması + hafıza güncelle

**Files:** (yalnızca doğrulama + hafıza)

- [ ] **Step 1: Tüm paket testleri**

```bash
TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore
TMPDIR=/private/tmp swift test --package-path SmokeTrackerData
```

Expected: Core **24**, Data **19**, hepsi PASS.

- [ ] **Step 2: Tam app derlemesi (iOS + watch + widget)**

```bash
xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker \
  -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj 2>&1 | tee /tmp/stb-build.log | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
grep -c "SmokeTrackerWatchWidget" /tmp/stb-build.log
```

Expected: `** BUILD SUCCEEDED **` ve widget grep > 0.

- [ ] **Step 3: Proje hafızasını güncelle**

`/Users/batu/.claude/projects/-Users-batu-projeler/memory/smoke-tracker-project.md` içinde Plan 4'ü TAMAM olarak işaretle; Plan 5 kapsamını (onboarding + izin + gizlilik + cihazlar-arası onay senkronu) yaz. Yeni öğrenilenler: widget extension hedefi `type: app-extension` + watch app'e `embed: true`; App Group entitlements yalnızca imzalı çalışmada geçerli, `SharedContainer` Documents'a düşer; complication tek-dokunuş `widgetURL` + watch app `onOpenURL` ile.

---

## Test stratejisi özeti

- **Test edilebilir (TDD, `swift test`):** `TapThrottle` (ilk kabul / aralık içi ret / sınırda kabul); `SharedContainer` (App Group yoksa Documents fallback, dosya adı korunur).
- **Yalnızca derleme:** widget extension hedefi + complication view'ları + `widgetURL`; watch app paylaşımlı depo + `onOpenURL` + `WidgetCenter` tazeleme.
- **Ertelenen (kullanıcı ortamı/cihaz düzelince):** Kadrana complication ekleyip dokununca app'in açılıp +1 işlemesi; complication'ın bugünkü sayıyı göstermesi (App Group provisioning gerektirir); gün dönümünde sayacın sıfırlanması; throttle ile çift-dokunuşun tek sayılması.

## Riskler / dikkat

- **Widget gömme zinciri:** `-target SmokeTracker` derlemesi gömülü watch'u ve onun gömülü widget'ını derlemeli; Task 3/5'te `grep -c SmokeTrackerWatchWidget` ile doğrulanır. Derlenmezse widget hedefi açıkça derlenir (`-arch` vermeden).
- **App Group provisioning:** Entitlements yalnızca imzalı çalıştırmada işler; bu ortamda derleme geçer ama complication canlı sayıyı ancak gerçek cihazda/imzalı gösterir (aksi halde `SharedContainer` Documents'a düşer ve widget app ile aynı dosyayı görmeyebilir).
- **`containerBackground`:** watchOS 10 widget'ları arka plan için uyarı verebilir; accessory aileleri için zorunlu değil, derlemeyi etkilemez. Gerekirse Plan 5'te eklenir.
