# Onboarding, İzinler ve Cihazlar-arası Onay Senkronu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** İlk açılışta gizlilik-odaklı bir onboarding akışı, watch tarafında proaktif Motion & Fitness izni ve iPhone ↔ Watch arasında eğitim-verisi onayının canlı senkronunu ekleyerek Faz 1 (MVP) kapsamını tamamlamak.

**Architecture:** İki yeni test edilebilir çekirdek parçası — onboarding-tamamlanma deposu (UserDefaults, gizlilik-önce) ve onay senkron codec'i (WCSession `applicationContext` sözlüğü) — ve bir saf izin-durumu modeli. Bunların üzerine app-glue: iPhone'da çok sayfalı onboarding (kök ekran `hasCompletedOnboarding` ile kapılı), her iki tarafta `updateApplicationContext` / `didReceiveApplicationContext` ile çift yönlü (latest-wins, döngüsüz) onay senkronu ve watch'ta `MotionPermissionStatus` ile sürülen proaktif izin + zarif düşüş (graceful degradation).

**Tech Stack:** Swift 6.0, Swift Testing (`@Suite`/`@Test`/`#expect`), SwiftUI (TabView `.page` stili), WatchConnectivity (`updateApplicationContext` / `didReceiveApplicationContext`), CoreMotion (`CMSensorRecorder.authorizationStatus()`).

---

## Mevcut durum ve kısıtlar (uygulamadan önce oku)

- **Faz 1'in 4 planı tamam ve main'de.** Bu plan Faz 1'in son parçası.
- **Simülatör bu Mac'te çalışmıyor.** Doğrulama yöntemi katmana göre:
  - **Paketler (Core/Data):** `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore` ve `--package-path SmokeTrackerData`. (`TMPDIR` şart — SwiftPM cache sandbox'ı için.) Codex sandbox'ında ek olarak: `--disable-sandbox` + `CLANG_MODULE_CACHE_PATH=/private/tmp/clang-module-cache`.
  - **App (iOS+gömülü watch+widget):** yeni app dosyası eklenince **önce** `xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp`, **sonra** derle:
    ```bash
    xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build \
      CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
    ```
    (`-sdk` override'ı KULLANMA. `-target SmokeTracker` derlemesi gömülü watch app'i + widget'ı da derler.)
- **`.xcodeproj` gitignore'da** (`SmokeTrackerApp/*.xcodeproj`) — asla commit etme; xcodegen üretir. Yalnızca kaynak + `project.yml` + entitlements + Info.plist commit edilir.
- **Codex sandbox'ta commit edemez** → testable tasklarda kodu Codex yazar, **commit'i controller yapar**.
- **Bu planda `project.yml` ve Info.plist değişmiyor:** yeni hedef yok; `NSMotionUsageDescription` zaten `Watch/Info.plist`'te mevcut; `applicationContext` App Group gerektirmez.
- **WCSession kısıtı:** süreç başına tek delegate. Watch'ta delegate `WatchSyncSender`, iPhone'da `PhoneSyncReceiver` — onay `applicationContext` işleme bu mevcut sınıflara eklenir.

---

## Dosya yapısı

**Yeni (test edilebilir çekirdek):**
- `SmokeTrackerCore/Sources/SmokeTrackerCore/Onboarding.swift` — `OnboardingStateStoring` protokolü.
- `SmokeTrackerCore/Sources/SmokeTrackerCore/MotionPermission.swift` — `MotionPermissionStatus` enum + `SessionAvailability` saf karar yardımcıları.
- `SmokeTrackerData/Sources/SmokeTrackerData/UserDefaultsOnboardingStore.swift` — onboarding-tamamlanma deposu.
- `SmokeTrackerData/Sources/SmokeTrackerData/ConsentSyncCodec.swift` — onay ↔ `applicationContext` sözlüğü codec'i.

**Yeni (app-glue):**
- `SmokeTrackerApp/iOS/OnboardingView.swift` — çok sayfalı onboarding ekranı.
- `SmokeTrackerApp/Watch/WatchMotionAuthorizer.swift` — CMSensorRecorder yetkisini `MotionPermissionStatus`'a çevirir.

**Değişen (app-glue):**
- `SmokeTrackerApp/iOS/PhoneModel.swift` — onboarding state + onay yayını/uygulaması.
- `SmokeTrackerApp/iOS/SmokeTrackerApp.swift` — kök onboarding kapısı.
- `SmokeTrackerApp/iOS/PhoneSyncReceiver.swift` — onay `applicationContext` alımı + `syncConsent`.
- `SmokeTrackerApp/Watch/WatchModel.swift` — onay yayını/uygulaması + Motion durumu.
- `SmokeTrackerApp/Watch/WatchSyncSender.swift` — onay `applicationContext` alımı + `syncConsent`.
- `SmokeTrackerApp/Watch/WatchSessionView.swift` — Motion izni durumuna göre UI.
- `SmokeTrackerApp/Watch/AccelerometerMotionRecorder.swift` — proaktif izin tetikleyici.

**Yeni testler:**
- `SmokeTrackerData/Tests/SmokeTrackerDataTests/UserDefaultsOnboardingStoreTests.swift`
- `SmokeTrackerData/Tests/SmokeTrackerDataTests/ConsentSyncCodecTests.swift`
- `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/MotionPermissionTests.swift`

---

# Faz A — Test edilebilir çekirdek (TDD)

## Task 1: Onboarding-tamamlanma deposu

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/Onboarding.swift`
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/UserDefaultsOnboardingStore.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/UserDefaultsOnboardingStoreTests.swift`

- [ ] **Step 1: Protokolü yaz (henüz gerçeklenmiş hali yok)**

`SmokeTrackerCore/Sources/SmokeTrackerCore/Onboarding.swift`:

```swift
import Foundation

/// İlk açılış onboarding'inin tamamlanıp tamamlanmadığını saklayan soyutlama.
/// Varsayılan: tamamlanmamış (false) — kullanıcı akışı görmeden uygulamaya düşmez.
public protocol OnboardingStateStoring: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
}
```

- [ ] **Step 2: Başarısız testi yaz**

`SmokeTrackerData/Tests/SmokeTrackerDataTests/UserDefaultsOnboardingStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct UserDefaultsOnboardingStoreTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "onboarding-test-\(UUID().uuidString)")!
    }

    @Test func defaultsToNotCompleted() {
        let store = UserDefaultsOnboardingStore(defaults: makeDefaults())
        #expect(store.hasCompletedOnboarding == false)
    }

    @Test func persistsCompletionAcrossInstances() {
        let defaults = makeDefaults()
        let store = UserDefaultsOnboardingStore(defaults: defaults)
        store.hasCompletedOnboarding = true
        #expect(store.hasCompletedOnboarding == true)

        let reopened = UserDefaultsOnboardingStore(defaults: defaults)
        #expect(reopened.hasCompletedOnboarding == true)
    }
}
```

- [ ] **Step 3: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData --filter UserDefaultsOnboardingStoreTests`
Expected: FAIL — "cannot find 'UserDefaultsOnboardingStore' in scope".

- [ ] **Step 4: Minimal gerçeklemeyi yaz**

`SmokeTrackerData/Sources/SmokeTrackerData/UserDefaultsOnboardingStore.swift`:

```swift
import Foundation
import SmokeTrackerCore

/// Onboarding-tamamlanma durumunu UserDefaults'ta saklar. Varsayılan: false.
public final class UserDefaultsOnboardingStore: OnboardingStateStoring {
    private let defaults: UserDefaults
    private let key = "has_completed_onboarding"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: key) }   // anahtar yoksa false
        set { defaults.set(newValue, forKey: key) }
    }
}
```

- [ ] **Step 5: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData --filter UserDefaultsOnboardingStoreTests`
Expected: PASS (2 test).

- [ ] **Step 6: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/Onboarding.swift \
        SmokeTrackerData/Sources/SmokeTrackerData/UserDefaultsOnboardingStore.swift \
        SmokeTrackerData/Tests/SmokeTrackerDataTests/UserDefaultsOnboardingStoreTests.swift
git commit -m "feat: add onboarding completion store"
```

---

## Task 2: Onay senkron codec'i (applicationContext)

**Files:**
- Create: `SmokeTrackerData/Sources/SmokeTrackerData/ConsentSyncCodec.swift`
- Test: `SmokeTrackerData/Tests/SmokeTrackerDataTests/ConsentSyncCodecTests.swift`

- [ ] **Step 1: Başarısız testi yaz**

`SmokeTrackerData/Tests/SmokeTrackerDataTests/ConsentSyncCodecTests.swift`:

```swift
import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct ConsentSyncCodecTests {
    @Test func roundTripTrue() {
        let context = ConsentSyncCodec.encode(trainingDataConsent: true)
        #expect(ConsentSyncCodec.decode(context) == true)
    }

    @Test func roundTripFalse() {
        let context = ConsentSyncCodec.encode(trainingDataConsent: false)
        #expect(ConsentSyncCodec.decode(context) == false)
    }

    @Test func encodesVersionField() {
        let context = ConsentSyncCodec.encode(trainingDataConsent: true)
        #expect((context["consentVersion"] as? Int) == 1)
    }

    @Test func decodeReturnsNilWhenVersionMissing() {
        #expect(ConsentSyncCodec.decode(["trainingDataConsent": true]) == nil)
    }

    @Test func decodeReturnsNilWhenValueWrongType() {
        let context: [String: Any] = ["consentVersion": 1, "trainingDataConsent": "yes"]
        #expect(ConsentSyncCodec.decode(context) == nil)
    }

    @Test func decodeReturnsNilForEmptyContext() {
        #expect(ConsentSyncCodec.decode([:]) == nil)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData --filter ConsentSyncCodecTests`
Expected: FAIL — "cannot find 'ConsentSyncCodec' in scope".

- [ ] **Step 3: Minimal gerçeklemeyi yaz**

`SmokeTrackerData/Sources/SmokeTrackerData/ConsentSyncCodec.swift`:

```swift
import Foundation

/// Eğitim-verisi onayını WCSession `applicationContext` sözlüğüne kodlar/çözer.
/// Sözlük "en son durum"u taşır (latest-wins); bozuk/eksik içerikte `decode`
/// nil döner ve çağıran tarafı sessizce yok sayar.
public enum ConsentSyncCodec {
    static let versionKey = "consentVersion"
    static let valueKey = "trainingDataConsent"
    static let version = 1

    public static func encode(trainingDataConsent: Bool) -> [String: Any] {
        [versionKey: version, valueKey: trainingDataConsent]
    }

    public static func decode(_ context: [String: Any]) -> Bool? {
        guard context[versionKey] as? Int == version else { return nil }
        return context[valueKey] as? Bool
    }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerData --filter ConsentSyncCodecTests`
Expected: PASS (6 test).

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerData/Sources/SmokeTrackerData/ConsentSyncCodec.swift \
        SmokeTrackerData/Tests/SmokeTrackerDataTests/ConsentSyncCodecTests.swift
git commit -m "feat: add consent sync codec for applicationContext"
```

---

## Task 3: Motion izin durumu + seans uygunluğu (saf model)

**Files:**
- Create: `SmokeTrackerCore/Sources/SmokeTrackerCore/MotionPermission.swift`
- Test: `SmokeTrackerCore/Tests/SmokeTrackerCoreTests/MotionPermissionTests.swift`

- [ ] **Step 1: Başarısız testi yaz**

`SmokeTrackerCore/Tests/SmokeTrackerCoreTests/MotionPermissionTests.swift`:

```swift
import Testing
@testable import SmokeTrackerCore

@Suite struct MotionPermissionTests {
    @Test func canStartWhenAuthorized() {
        #expect(SessionAvailability.canStartSession(motion: .authorized) == true)
    }

    @Test func canStartWhenNotDetermined() {
        // İlk seans başlatma izin penceresini açar; bu yüzden engellenmez.
        #expect(SessionAvailability.canStartSession(motion: .notDetermined) == true)
    }

    @Test func cannotStartWhenDeniedOrRestricted() {
        #expect(SessionAvailability.canStartSession(motion: .denied) == false)
        #expect(SessionAvailability.canStartSession(motion: .restricted) == false)
    }

    @Test func promptsOnlyWhenNotDetermined() {
        #expect(SessionAvailability.shouldPromptForMotion(.notDetermined) == true)
        #expect(SessionAvailability.shouldPromptForMotion(.authorized) == false)
        #expect(SessionAvailability.shouldPromptForMotion(.denied) == false)
        #expect(SessionAvailability.shouldPromptForMotion(.restricted) == false)
    }

    @Test func blockedOnlyWhenDeniedOrRestricted() {
        #expect(SessionAvailability.isBlocked(.denied) == true)
        #expect(SessionAvailability.isBlocked(.restricted) == true)
        #expect(SessionAvailability.isBlocked(.authorized) == false)
        #expect(SessionAvailability.isBlocked(.notDetermined) == false)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore --filter MotionPermissionTests`
Expected: FAIL — "cannot find 'SessionAvailability' / 'MotionPermissionStatus' in scope".

- [ ] **Step 3: Minimal gerçeklemeyi yaz**

`SmokeTrackerCore/Sources/SmokeTrackerCore/MotionPermission.swift`:

```swift
import Foundation

/// Motion & Fitness yetkisinin platform-bağımsız durumu. CoreMotion'a bağımlı
/// olmadan UI ve karar mantığı test edilebilsin diye saf bir enum.
public enum MotionPermissionStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Seans modunun, Motion izin durumuna göre uygunluğunu belirleyen saf
/// fonksiyonlar. Zarif düşüş (graceful degradation): izin reddedilse bile
/// tek-dokunuş +1 her zaman çalışmaya devam eder; yalnızca seans kapanır.
public enum SessionAvailability {
    /// Seans başlatılabilir mi? `notDetermined` izin penceresini açacağı için
    /// engellenmez; yalnızca açıkça reddedilmiş/kısıtlı durumlar engeller.
    public static func canStartSession(motion: MotionPermissionStatus) -> Bool {
        switch motion {
        case .authorized, .notDetermined: return true
        case .denied, .restricted: return false
        }
    }

    /// Kullanıcıya proaktif "izin ver" istemi gösterilmeli mi?
    public static func shouldPromptForMotion(_ status: MotionPermissionStatus) -> Bool {
        status == .notDetermined
    }

    /// İzin kalıcı olarak kapalı mı? (Ayarlar'a yönlendirme metni için.)
    public static func isBlocked(_ status: MotionPermissionStatus) -> Bool {
        status == .denied || status == .restricted
    }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore --filter MotionPermissionTests`
Expected: PASS (5 test).

- [ ] **Step 5: Tüm paket testlerinin hâlâ geçtiğini doğrula**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore`
Expected: PASS (önceki 24 + yeni 5 = 29 test).

- [ ] **Step 6: Commit**

```bash
git add SmokeTrackerCore/Sources/SmokeTrackerCore/MotionPermission.swift \
        SmokeTrackerCore/Tests/SmokeTrackerCoreTests/MotionPermissionTests.swift
git commit -m "feat: add motion permission status and session availability rules"
```

---

# Faz B — iPhone onboarding akışı (app-glue, yalnızca derleme)

## Task 4: Onboarding ekranı + kök kapı

**Files:**
- Modify: `SmokeTrackerApp/iOS/PhoneModel.swift`
- Create: `SmokeTrackerApp/iOS/OnboardingView.swift`
- Modify: `SmokeTrackerApp/iOS/SmokeTrackerApp.swift`

Bağlam: `PhoneModel` zaten `@MainActor @Observable`; `trainingDataConsent` mevcut ve `UserDefaultsConsentStore`'a yazıyor. Onboarding'in son sayfasındaki onay toggle'ı aynı `trainingDataConsent`'e bağlanır.

- [ ] **Step 1: PhoneModel'e onboarding state ekle**

`SmokeTrackerApp/iOS/PhoneModel.swift` — `private let consent = UserDefaultsConsentStore()` satırının hemen altına yeni depo ekle:

```swift
    private let consent = UserDefaultsConsentStore()
    private let onboardingStore = UserDefaultsOnboardingStore()
```

`var trainingDataConsent: Bool { ... }` bloğunun hemen altına yayınlanan durumu ekle:

```swift
    var hasCompletedOnboarding: Bool
```

`init()` içinde, `self.trainingDataConsent = consent.trainingDataConsent` satırının hemen altına ekle:

```swift
        self.hasCompletedOnboarding = onboardingStore.hasCompletedOnboarding
```

Sınıfın sonuna (deleteAllTrainingData'dan sonra) yeni metodu ekle:

```swift
    /// Onboarding'i tamamlandı olarak işaretler; kök ekran TodayView'a geçer.
    func completeOnboarding() {
        onboardingStore.hasCompletedOnboarding = true
        hasCompletedOnboarding = true
    }
```

- [ ] **Step 2: Onboarding ekranını oluştur**

`SmokeTrackerApp/iOS/OnboardingView.swift`:

```swift
import SwiftUI

/// İlk açılış akışı: ne yaptığı, gizlilik ve eğitim-verisi onayı. Son sayfada
/// "Başla" → model.completeOnboarding().
struct OnboardingView: View {
    @Bindable var model: PhoneModel
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            welcome.tag(0)
            howItWorks.tag(1)
            privacy.tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "lungs.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Sigara Takip")
                .font(.largeTitle.bold())
            Text("Gün içinde kaç sigara/IQOS içtiğini sade biçimde takip et. Hedef yok, yargı yok — sadece farkındalık.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            nextHint
        }
        .padding(32)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Nasıl çalışır")
                .font(.title.bold())
            Label("Saat kadranındaki complication'a dokun → anında +1.", systemImage: "plus.circle.fill")
            Label("İstersen \"Seans\" başlat; bilek hareketi kaydedilir, bitince +1 işlenir.", systemImage: "record.circle")
            Label("Tüm veriler cihazında kalır (local-first). Satış yok.", systemImage: "lock.fill")
            Spacer()
            nextHint
        }
        .padding(32)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gizlilik ve onay")
                .font(.title.bold())
            Text("Sensörlü seanslardaki ham hareket verisi, ileride sigara içme hareketini otomatik tanımak için kullanılabilir. Bu tamamen opsiyoneldir ve yalnızca açık iznine bağlıdır; istediğin an silebilirsin.")
                .foregroundStyle(.secondary)
            Toggle("Eğitim verisi toplamaya izin ver", isOn: $model.trainingDataConsent)
            Spacer()
            Button {
                model.completeOnboarding()
            } label: {
                Text("Başla")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private var nextHint: some View {
        Text("Devam etmek için kaydır")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 3: Kök ekrana onboarding kapısı koy**

`SmokeTrackerApp/iOS/SmokeTrackerApp.swift` içindeki `WindowGroup { ... }` gövdesini değiştir:

```swift
        WindowGroup {
            if model.hasCompletedOnboarding {
                TodayView(model: model)
            } else {
                OnboardingView(model: model)
            }
        }
```

- [ ] **Step 4: Projeyi yeniden üret**

Run: `xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp`
Expected: "Created project at .../SmokeTracker.xcodeproj". (OnboardingView.swift `iOS` klasöründe olduğu için otomatik dahil edilir.)

- [ ] **Step 5: Derlemeyi doğrula**

Run:
```bash
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SmokeTrackerApp/iOS/PhoneModel.swift \
        SmokeTrackerApp/iOS/OnboardingView.swift \
        SmokeTrackerApp/iOS/SmokeTrackerApp.swift
git commit -m "feat: add first-launch onboarding flow on iPhone"
```

---

# Faz C — Cihazlar-arası onay senkronu (app-glue, yalnızca derleme)

> Tasarım: onay tek bir Bool'dur ve `updateApplicationContext` ile taşınır (latest-wins). Döngüyü önlemek için her iki model de uzaktan gelen değeri uygularken yayını bastırır (`suppressConsentBroadcast`).

## Task 5: Watch tarafı onay yayını + alımı

**Files:**
- Modify: `SmokeTrackerApp/Watch/WatchSyncSender.swift`
- Modify: `SmokeTrackerApp/Watch/WatchModel.swift`

- [ ] **Step 1: WatchSyncSender'a onay kanalı ekle**

`SmokeTrackerApp/Watch/WatchSyncSender.swift` — sınıfın en üstüne (`override init()`'in üstüne) geri-çağrıyı ekle:

```swift
    /// iPhone'dan applicationContext ile gelen onay değişimini WatchModel'e
    /// iletir. WatchModel init'te atar.
    var onConsentChange: ((Bool) -> Void)?
```

`sendTrainingSession(_:)` metodunun hemen altına onay gönderimini ekle:

```swift
    /// Yerel onay değişimini iPhone'a taşır. applicationContext son durumu tutar;
    /// karşı taraf uyandığında teslim alır (latest-wins).
    func syncConsent(_ on: Bool) {
        guard WCSession.isSupported() else { return }
        try? WCSession.default.updateApplicationContext(
            ConsentSyncCodec.encode(trainingDataConsent: on)
        )
    }
```

`activationDidCompleteWith` delegate metodunun hemen altına onay alımını ekle:

```swift
    /// iPhone'dan gelen onay durumunu çöz ve MainActor'da WatchModel'e ilet.
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let value = ConsentSyncCodec.decode(applicationContext) else { return }
        Task { @MainActor in
            self.onConsentChange?(value)
        }
    }
```

- [ ] **Step 2: WatchModel'i çift yönlü onaya bağla**

`SmokeTrackerApp/Watch/WatchModel.swift`:

Depo alanlarının yanına (örn. `complicationThrottle` satırının altına) döngü-koruma bayrağını ekle:

```swift
    private var suppressConsentBroadcast = true   // init sırasında yayını bastır
```

`trainingDataConsent` özelliğinin `didSet`'ini güncelle (yayını ekle):

```swift
    var trainingDataConsent: Bool {
        didSet {
            consent.trainingDataConsent = trainingDataConsent
            guard !suppressConsentBroadcast else { return }
            sender.syncConsent(trainingDataConsent)
        }
    }
```

`init()` içinde `refresh()` çağrısının **hemen üstüne** geri-çağrıyı bağla, **altına** bayrağı serbest bırak:

```swift
        self.trainingDataConsent = consent.trainingDataConsent
        self.sender.onConsentChange = { [weak self] value in
            self?.applyRemoteConsent(value)
        }
        refresh()
        suppressConsentBroadcast = false
```

`refresh()` metodunun hemen üstüne uzaktan-onay uygulayıcıyı ekle:

```swift
    /// iPhone'dan gelen onayı yerelde uygular; yeniden yayın yapmaz (döngü yok).
    func applyRemoteConsent(_ value: Bool) {
        guard value != trainingDataConsent else { return }
        suppressConsentBroadcast = true
        trainingDataConsent = value   // store'a yazılır, tekrar yayınlanmaz
        suppressConsentBroadcast = false
    }
```

- [ ] **Step 3: Projeyi yeniden üret**

Run: `xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp`
Expected: proje üretildi. (Dosyalar zaten mevcut yollarda — yeni dosya yok, yine de güvenli.)

- [ ] **Step 4: Derlemeyi doğrula**

Run:
```bash
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerApp/Watch/WatchSyncSender.swift \
        SmokeTrackerApp/Watch/WatchModel.swift
git commit -m "feat: broadcast and apply training consent on watch via applicationContext"
```

---

## Task 6: iPhone tarafı onay yayını + alımı

**Files:**
- Modify: `SmokeTrackerApp/iOS/PhoneSyncReceiver.swift`
- Modify: `SmokeTrackerApp/iOS/PhoneModel.swift`

- [ ] **Step 1: PhoneSyncReceiver'a onay kanalı ekle**

`SmokeTrackerApp/iOS/PhoneSyncReceiver.swift`:

`private let onChange: () -> Void` satırının üstüne yeni alanı ekle:

```swift
    private let onConsentChange: (Bool) -> Void
```

`init`'i yeni parametreyle güncelle (sırayı koru: coordinator, archive, onConsentChange, onChange):

```swift
    init(
        coordinator: SyncCoordinator,
        archive: TrainingDataArchiving,
        onConsentChange: @escaping (Bool) -> Void,
        onChange: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.archive = archive
        self.onConsentChange = onConsentChange
        self.onChange = onChange
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
```

`didReceive file:` delegate metodunun hemen altına onay gönderimi ve alımını ekle:

```swift
    /// Yerel (onboarding/ayar) onay değişimini watch'a taşır.
    func syncConsent(_ on: Bool) {
        guard WCSession.isSupported() else { return }
        try? WCSession.default.updateApplicationContext(
            ConsentSyncCodec.encode(trainingDataConsent: on)
        )
    }

    /// Watch'tan gelen onay durumunu çöz ve MainActor'da PhoneModel'e ilet.
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let value = ConsentSyncCodec.decode(applicationContext) else { return }
        Task { @MainActor in
            self.onConsentChange(value)
        }
    }
```

- [ ] **Step 2: PhoneModel'i çift yönlü onaya bağla**

`SmokeTrackerApp/iOS/PhoneModel.swift`:

`onboardingStore` satırının altına döngü-koruma bayrağını ekle:

```swift
    private var suppressConsentBroadcast = true   // init sırasında yayını bastır
```

`trainingDataConsent` özelliğinin `didSet`'ini güncelle (yayını ekle):

```swift
    var trainingDataConsent: Bool {
        didSet {
            consent.trainingDataConsent = trainingDataConsent
            guard !suppressConsentBroadcast else { return }
            receiver?.syncConsent(trainingDataConsent)
        }
    }
```

`init()` içinde receiver kurulumunu yeni parametreyle güncelle ve sonunda bayrağı serbest bırak. `self.receiver = ...` bloğunu şununla değiştir:

```swift
        self.receiver = PhoneSyncReceiver(
            coordinator: coordinator,
            archive: archive,
            onConsentChange: { [weak self] value in
                self?.applyRemoteConsent(value)
            },
            onChange: { [weak self] in
                self?.refresh()
            }
        )
        suppressConsentBroadcast = false
```

`completeOnboarding()` metodunun hemen üstüne uzaktan-onay uygulayıcıyı ekle:

```swift
    /// Watch'tan gelen onayı yerelde uygular; yeniden yayın yapmaz (döngü yok).
    func applyRemoteConsent(_ value: Bool) {
        guard value != trainingDataConsent else { return }
        suppressConsentBroadcast = true
        trainingDataConsent = value
        suppressConsentBroadcast = false
    }
```

- [ ] **Step 3: Projeyi yeniden üret**

Run: `xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp`
Expected: proje üretildi.

- [ ] **Step 4: Derlemeyi doğrula**

Run:
```bash
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```
Expected: `** BUILD SUCCEEDED **`. (Onboarding son sayfasındaki onay toggle'ı artık watch'a taşınır — tek yönlü hata düzeldi.)

- [ ] **Step 5: Commit**

```bash
git add SmokeTrackerApp/iOS/PhoneSyncReceiver.swift \
        SmokeTrackerApp/iOS/PhoneModel.swift
git commit -m "feat: broadcast and apply training consent on iPhone via applicationContext"
```

---

# Faz D — Watch'ta proaktif Motion izni (app-glue, yalnızca derleme)

## Task 7: Motion durum okuma + proaktif istem + zarif düşüş

**Files:**
- Create: `SmokeTrackerApp/Watch/WatchMotionAuthorizer.swift`
- Modify: `SmokeTrackerApp/Watch/AccelerometerMotionRecorder.swift`
- Modify: `SmokeTrackerApp/Watch/WatchModel.swift`
- Modify: `SmokeTrackerApp/Watch/WatchSessionView.swift`

- [ ] **Step 1: CMSensorRecorder yetkisini saf enum'a çeviren yardımcıyı oluştur**

`SmokeTrackerApp/Watch/WatchMotionAuthorizer.swift`:

```swift
import CoreMotion
import SmokeTrackerCore

/// CMSensorRecorder'ın Motion & Fitness yetki durumunu platform-bağımsız
/// `MotionPermissionStatus`'a çevirir (UI ve karar mantığı için).
enum WatchMotionAuthorizer {
    static var status: MotionPermissionStatus {
        switch CMSensorRecorder.authorizationStatus() {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}
```

- [ ] **Step 2: Recorder'a proaktif izin tetikleyici ekle**

`SmokeTrackerApp/Watch/AccelerometerMotionRecorder.swift` — `startRecording()` metodunun hemen üstüne ekle:

```swift
    /// Motion & Fitness iznini proaktif olarak ister. CMSensorRecorder'ın ayrı
    /// bir "izin iste" API'si yoktur; sistem istemi yalnızca recordAccelerometer
    /// ile açılır. Bu yüzden kısa, zararsız (okunmayan) bir kayıt başlatarak
    /// soruyu öne çekeriz; izin reddedilirse kayıt zaten oluşmaz.
    func requestAuthorization() {
        recorder.recordAccelerometer(forDuration: 60)
    }
```

- [ ] **Step 3: WatchModel'e Motion durumu ve istem aksiyonlarını ekle**

`SmokeTrackerApp/Watch/WatchModel.swift`:

`import` satırlarında `SmokeTrackerCore` zaten var (MotionPermissionStatus oradan gelir — ek import gerekmez).

`var isRecordingSession: Bool = false` satırının altına yayınlanan durumu ekle:

```swift
    var motionStatus: MotionPermissionStatus = .notDetermined
```

`init()` içinde `refresh()` çağrısından **önce** Motion durumunu da yükle. `self.sessionRecorder = ...` satırının altına ekle:

```swift
        self.motionStatus = WatchMotionAuthorizer.status
```

`startSession()`'ı izin engeline karşı koru — mevcut metodu şununla değiştir:

```swift
    /// Sensörlü seansı başlatır (ilk kayıt Motion iznini tetikler). İzin kalıcı
    /// kapalıysa seans açılmaz; +1 yine de çalışır.
    func startSession() {
        motionStatus = WatchMotionAuthorizer.status
        guard SessionAvailability.canStartSession(motion: motionStatus) else { return }
        sessionRecorder.start()
        isRecordingSession = true
    }
```

`refresh()` metodunun hemen üstüne durum yenileyici ve proaktif istem ekle:

```swift
    /// Motion izin durumunu güncel CMSensorRecorder yetkisinden tazeler.
    func refreshMotionStatus() {
        motionStatus = WatchMotionAuthorizer.status
    }

    /// Kullanıcı isteğiyle Motion iznini proaktif tetikler, sonra durumu tazeler.
    func requestMotionPermission() {
        motionRecorder.requestAuthorization()
        refreshMotionStatus()
    }
```

- [ ] **Step 4: WatchSessionView'i izin durumuna göre güncelle**

`SmokeTrackerApp/Watch/WatchSessionView.swift` — dosyanın en üstündeki `import SwiftUI` satırının altına ekle:

```swift
import SmokeTrackerCore
```

`else` (kayıt sürmüyor) dalını, "Seans başlat" butonundan önce izin durumunu gösterecek ve engelliyse butonu kapatacak şekilde değiştir. Mevcut `else { ... }` bloğunun gövdesini şununla değiştir:

```swift
            } else {
                Text("Sensörlü seans")
                    .font(.headline)
                Text("Başlat; içerken bilek hareketini kaydedelim, bitince +1 işlenir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if SessionAvailability.isBlocked(model.motionStatus) {
                    Text("Hareket izni kapalı. Seans için Watch Ayarları > Gizlilik ve Güvenlik > Hareket ve Fitness'ten aç. \"+1\" her zaman çalışır.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if SessionAvailability.shouldPromptForMotion(model.motionStatus) {
                    Button {
                        model.requestMotionPermission()
                    } label: {
                        Label("Hareket iznini ver", systemImage: "hand.raised")
                            .frame(maxWidth: .infinity)
                    }
                }

                Button {
                    model.startSession()
                } label: {
                    Label("Seans başlat", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(SessionAvailability.isBlocked(model.motionStatus))

                Toggle("Eğitim verisi topla", isOn: $model.trainingDataConsent)
                    .font(.caption)
            }
```

`VStack { ... }`'in kapanışındaki `.padding()`/`.navigationTitle("Seans")` zincirine durum tazeleme ekle (navigationTitle satırının hemen altına):

```swift
        .onAppear { model.refreshMotionStatus() }
```

- [ ] **Step 5: Projeyi yeniden üret**

Run: `xcodegen generate --spec SmokeTrackerApp/project.yml --project SmokeTrackerApp`
Expected: proje üretildi (WatchMotionAuthorizer.swift `Watch` klasöründe otomatik dahil).

- [ ] **Step 6: Derlemeyi doğrula**

Run:
```bash
xcodebuild -project SmokeTrackerApp/SmokeTracker.xcodeproj -target SmokeTracker -arch arm64 -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO SYMROOT=/tmp/stb/sym OBJROOT=/tmp/stb/obj
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add SmokeTrackerApp/Watch/WatchMotionAuthorizer.swift \
        SmokeTrackerApp/Watch/AccelerometerMotionRecorder.swift \
        SmokeTrackerApp/Watch/WatchModel.swift \
        SmokeTrackerApp/Watch/WatchSessionView.swift
git commit -m "feat: proactive motion permission and graceful degradation on watch"
```

---

# Kapanış

- [ ] **Tüm paket testleri yeşil**

Run: `TMPDIR=/private/tmp swift test --package-path SmokeTrackerCore && TMPDIR=/private/tmp swift test --package-path SmokeTrackerData`
Expected: Core **29** test PASS (önceki 24 + MotionPermission 5), Data **27** test PASS (önceki 19 + onboarding 2 + consent-codec 6). _Not: gerçek sayıları çıktıdan doğrula; düşüş varsa düzelt._

- [ ] **App derlemesi yeşil**

Run: yukarıdaki `xcodebuild` komutu. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Final code review** (subagent-driven-development gereği): tüm değişiklik için tek bir kod-kalite incelemesi.

- [ ] **Branch'i bitir**: superpowers:finishing-a-development-branch.

## Bu planda bilinçli OLMAYANLAR (YAGNI)
- Onay senkronunda zaman-damgalı çakışma çözümü — `updateApplicationContext` latest-wins yeterli (MVP).
- watchOS'ta bildirim izni — Faz 1'de bildirim yok.
- Onboarding'i tekrar gösterme/sıfırlama ekranı (Ayarlar) — gerekirse sonra.
- Uçtan uca cihaz testi — bu ortamda simülatör çalışmıyor; kullanıcı ortamı düzeltince doğrulanacak.

## Doğrulamanın sınırı (dürüstlük notu)
`applicationContext` teslimi, proaktif Motion istemi ve onboarding akışı **yalnızca gerçek cihazda/eşli simülatörde** uçtan uca doğrulanabilir. Bu planın doğrulaması derleme + paket birim testleriyle sınırlıdır; WCSession teslim davranışı ve izin istemleri cihaz gerektirir.
