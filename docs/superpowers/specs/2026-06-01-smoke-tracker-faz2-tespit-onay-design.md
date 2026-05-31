# Faz 2.1 — Pasif Aday Tespiti + Onay Döngüsü (Tasarım)

**Tarih:** 2026-06-01
**Durum:** Onaylandı (brainstorming) → uygulama planına geçilecek
**Bağlam:** Bu doküman, Faz 2'nin **ilk alt-projesini (2.1)** tanımlar. Genel ürün
tasarımı için bkz. `2026-05-31-sigara-tespit-watch-design.md` (Faz 1 / MVP).

## Amaç

Kullanıcı bileğindeki ivmeölçer verisinden, arka planda ve pil-dostu biçimde
olası sigara/IQOS içme anlarını **aday** olarak yakalamak; her aday için
"Sigara içtin mi?" diye **onay** sormak; onay sonucunu hem **+1 sayım** hem de
**dengeli etiketli eğitim verisi** (Evet → pozitif, Hayır → negatif) üretmek için
kullanmak. Böylece Faz 2.2'nin (ML modeli) muhtaç olduğu iki-sınıflı veri,
kullanıcıyı yormadan kendiliğinden birikir.

## Faz 2 alt-proje ayrışımı

Faz 2 üç bağımsız spec→plan→uygulama döngüsüne bölünmüştür:

| Alt-proje | İçerik | ML? |
|-----------|--------|-----|
| **2.1 (bu doküman)** | Pasif aday tespiti + onay + geri besleme verisi | Hayır — saf heuristik detektör |
| **2.2** | Offline eğitim hattı (Mac CreateML → Core ML) + heuristiği modelle değiştirme | Evet — 2.1'in topladığı veriyle |
| **2.3** | Sürekli kişiselleştirme / doğruluk artırma | Evet |

2.1 önce gelir çünkü hem hemen sevk edilebilir bir özellik üretir hem de 2.2'nin
muhtaç olduğu dengeli (pozitif **+ negatif**) etiketli veriyi otomatik toplar.

## Temel kararlar (özet)

| Konu | Karar | Gerekçe |
|------|-------|---------|
| Cold-start stratejisi | **Onay-döngüsü-önce** (ilk sürümde ML yok) | Sıfır/tek-sınıf veriyle başlanır; onaylar dengeli veri üretir |
| Detektör | Saf heuristik, `SmokeDetecting` protokolü arkasında | 2.2'de aynı protokole Core ML geçer; üst katman değişmez |
| Arka plan modeli | **Periyodik yenileme** (`WKApplicationRefreshBackgroundTask`) | Gerçekten pasif + pil-dostu; CMSensorRecorder'ın toplu doğasına uyar |
| Onay zamanlaması | Geriye dönük, gecikmeli ("~15:42 civarı içtin mi?") | Sayım için anlık tespit gerekmez; pil kazanılır |
| Sayım kuralı | **Onaysız asla sayılmaz** | Hassas sağlık verisi + kullanıcı güveni; sessiz +1 yok |
| Heuristik posizyonu | **Recall-öncelikli** (fazla sor, kullanıcı eletsin) | "Hayır" cevapları bedava negatif veri üretir |
| Bildirim yorgunluğu | Günlük üst sınır + sessiz saatler | Recall-öncelikli detektörün yan etkisini dengeler |
| Negatif etiket | `"sigara_degil"` (mevcut `TrainingSession.label: String`) | Struct değişikliği yok; 2.2 için iki-sınıflı veri |

## Mimari

**Çekirdek fikir:** Detektör, değiştirilebilir bir `SmokeDetecting` protokolünün
arkasındadır. 2.1'de gerçeklemesi saf bir heuristik; 2.2'de aynı protokolün
arkasına eğitilmiş Core ML modeli geçer ve üst katman (zamanlayıcı, bildirim,
onay akışı) hiç değişmez.

```
┌──────────────── Apple Watch (arka plan) ────────────────┐
│  WKApplicationRefreshBackgroundTask (~15-30 dk)          │
│    1. cursor → CMSensorRecorder.accelerometerData(...)   │
│    2. [MotionSample]                                      │
│    3. SmokeDetecting.detect(in:) → [CandidateWindow]     │
│    4. CandidateFilter(after: cursor) → yeni adaylar      │
│    5. her aday: PendingCandidateStore.save               │
│                 + (NotificationBudget izniyle) bildirim  │
│    6. cursor güncelle → setTaskCompleted → yeniden planla│
└───────────────────────────┬─────────────────────────────┘
            "Sigara içtin mi? (~15:42)"  [Evet] [Hayır]
                            │
                            ▼  (kullanıcı dakikalar sonra yanıtlar)
┌──────────────── Onay işleme (watch) ────────────────────┐
│  candidateID → PendingCandidateStore.lookup             │
│  ConfirmationFlow.outcome(for:result:)                  │
│   • Evet  → SmokingEvent(.autoConfirmed, t=pencere)     │
│             + TrainingSession(label:"sigara")           │
│   • Hayır → (olay yok) + TrainingSession("sigara_degil")│
│  → +1/complication reload + iPhone'a senkron            │
│  → PendingCandidateStore.remove                         │
└───────────────────────────┬─────────────────────────────┘
                            │ WatchConnectivity (mevcut)
                            ▼
┌──────────────────── iPhone Companion ───────────────────┐
│  Olay → EventStore (mevcut)                             │
│  TrainingSession → arşiv (pozitif + negatif, izinle)    │
│  → Faz 2.2 eğitim veri kümesi                           │
└──────────────────────────────────────────────────────────┘
```

## Bileşenler

Her bileşen tek sorumluluk taşır, iyi tanımlı arayüzle haberleşir, mümkün
olduğunca ayrı test edilir. **Saf çekirdek mantık** Mac'te `swift test` ile
doğrulanır; **cihaz-glue** yalnızca gerçek cihazda manuel doğrulanır.

### Core (`SmokeTrackerCore`) — saf, TDD ile test edilir

- **`SmokingEvent.swift` (değişiklik):** `EventSource` enum'una `case autoConfirmed`
  eklenir (otomatik tespitten **onaylanmış** olay).
- **`SmokeDetection.swift` (yeni):**
  - `public protocol SmokeDetecting { func detect(in samples: [MotionSample]) -> [CandidateWindow] }`
  - `public struct CandidateWindow: Codable, Equatable, Sendable { let start: Date; let end: Date; let samples: [MotionSample]; let confidence: Double }`
- **`HeuristicSmokeDetector.swift` (yeni):** `SmokeDetecting`'in saf gerçeklemesi.
  Kayan pencerede (ör. ~10 sn) tekrarlı "kol kaldır → ağız civarı duraklama →
  indir" döngüsü arar; ~birkaç dakikalık aralıkta ≥N döngü → bir `CandidateWindow`.
  `confidence`, döngü sayısının beklenene oranı gibi basit bir skordur. Tüm
  eşikler bir `DetectorConfig` struct'ında **ayarlanabilir** tutulur.
  - **Dürüstlük notu:** Kesin eşikler cihaz verisi olmadan kalibre edilemez. İlk
    sürüm kasıtlı olarak basit ve recall-önceliklidir; gerçek değerler cihazda
    toplanan veriyle ayarlanacaktır. Heuristiğin görevi "mükemmel tespit" değil,
    onaya değer aday üretmektir.
- **`CandidateFilter.swift` (yeni):** saf imleç/dedup mantığı —
  `filter(_ candidates: [CandidateWindow], after cursor: Date) -> [CandidateWindow]`.
  Çakışan batch'lerde (CMSensorRecorder pencereleri örtüşebilir) aynı pencerenin
  tekrar tespitini eler; yalnızca `cursor`'dan sonra başlayan adayları döndürür.
- **`ConfirmationFlow.swift` (yeni):**
  - `public enum ConfirmationResult: Sendable { case smoked, notSmoked }`
  - `public enum TrainingLabel { static let smoking = "sigara"; static let notSmoking = "sigara_degil" }`
  - Saf eşleme: `outcome(for candidate: PendingCandidate, result: ConfirmationResult) -> (event: SmokingEvent?, training: TrainingSession)`.
    `smoked` → `SmokingEvent(source:.autoConfirmed, timestamp: candidate.window.start)` + `TrainingSession(label: .smoking)`;
    `notSmoked` → `event = nil` + `TrainingSession(label: .notSmoking)`.
- **`PendingCandidate.swift` (yeni, Core, Codable):**
  `public struct PendingCandidate: Identifiable, Codable, Sendable, Equatable { let id: UUID; let detectedAt: Date; let window: CandidateWindow }`.
- **`NotificationBudget.swift` (yeni):** saf politika —
  `canNotify(sentToday: Int, hour: Int, config: BudgetConfig) -> Bool`. Günlük
  üst sınır + sessiz saatler (ör. 23:00–07:00). Bildirim yorgunluğuna karşı kapı.
- **`PendingCandidateStoring` protokolü (Core):** `save/all/remove(id:)` — gerçeklemesi Data'da.

### Data (`SmokeTrackerData`) — kalıcılık

- **`PendingCandidateStore.swift` (yeni):** watch'ta onay bekleyen adayların disk
  deposu (aday başına 1 JSON, `FileEventStore` deseni). Onay, app kapalıyken
  bildirimle gelebileceğinden aday **kalıcı** olmalıdır. `PendingCandidateStoring`
  gerçeklemesi. (Ham pencere bildirime sığmaz; bildirim yalnızca `candidateID`
  taşır, gövde diskten okunur.)
- **`DetectionCursorStore.swift` (yeni):** son işlenen imleç zamanını kalıcı
  tutar (UserDefaults, `UserDefaultsConsentStore` deseni). `get/set`.

### Watch (glue — yalnızca cihazda doğrulanır)

- **`BackgroundDetectionScheduler.swift` (yeni):** `WKApplicationRefreshBackgroundTask`
  planlar ve işler. Uyanınca: `DetectionCursorStore`'dan cursor →
  `CMSensorRecorder.accelerometerData(from: cursor, to: now)` → `MotionSample`
  dizisine çevir (mevcut `AccelerometerMotionRecorder` çevirme mantığı yeniden
  kullanılır) → `detector.detect` → `CandidateFilter` → her yeni aday:
  `PendingCandidateStore.save` + (`NotificationBudget` izniyle)
  `SmokeNotificationScheduler` → cursor güncelle → `setTaskCompleted(...)` →
  bir sonraki yenilemeyi planla.
- **`SmokeNotificationScheduler.swift` (yeni):** `UNUserNotificationCenter`.
  Kategori `SMOKE_CONFIRM`, aksiyonlar **Evet** / **Hayır**,
  `userInfo: ["candidateID": uuid.uuidString]`. Bildirim metni tespit saatini
  içerir ("Sigara içtin mi? (~15:42)"). İzin isteği (`.alert`, `.sound`).
- **`WatchModel` (değişiklik):** `confirmCandidate(id:result:)` —
  `PendingCandidateStore`'dan adayı al → `ConfirmationFlow.outcome` →
  `smoked` ise olayı işle (mevcut `logOne` mantığı gibi: store.add +
  `sender.send` + `refresh()` + `WidgetCenter.reloadAllTimelines()`) ve izin
  varsa `TrainingSession(label:"sigara")` gönder; `notSmoked` ise yalnızca
  `TrainingSession(label:"sigara_degil")` gönder (olay yok); ardından pending'i
  `remove`. Bildirim delegate'i (uygulama/extension delegate) bu metodu çağırır.

### iOS

- **Arşiv:** Mevcut `TrainingDataArchiving`/`FileTrainingDataArchive` zaten generic
  `label: String` ile **pozitif + negatif** seansları tutar → struct değişikliği
  yok. `TrainingDataView`'a etiket başına sayı (pozitif/negatif) gösterimi eklenir.
- **`OnboardingView` (değişiklik):** "Arka planda otomatik tespit + bildirimle
  onay" açıklayan bir sayfa. Bildirim izni **watch'ta** istenir (bildirimi watch
  atar); onboarding kullanıcıyı buna yönlendirir.

## Veri akışı (özet)

1. Arka plan yenileme tetiklenir (~15-30 dk, sistemce kısıtlı).
2. `[cursor, now]` ivmeölçer geçmişi toplu çekilir.
3. Heuristik detektör aday pencere(ler) üretir; `CandidateFilter` cursor'dan
   eski/çakışan adayları eler.
4. Her yeni aday diske `PendingCandidate` olarak yazılır; bütçe izin veriyorsa
   "Sigara içtin mi? (~HH:MM)" bildirimi (Evet/Hayır) atılır.
5. Cursor ilerletilir, sonraki yenileme planlanır.
6. Kullanıcı (dakikalar sonra olabilir) yanıtlar:
   - **Evet** → `+1` olay (`source:.autoConfirmed`, `timestamp` = pencere zamanı)
     + `TrainingSession(label:"sigara")` iPhone'a.
   - **Hayır** → olay yok + `TrainingSession(label:"sigara_degil")` iPhone'a.
   - **Yanıtsız / zaman aşımı** → aday sessizce düşer (etiketsiz).

## Hata yönetimi

- **Çift sayım:** Kullanıcı tespit anında zaten manuel +1 yaptıysa onaya "Hayır"
  der; onay kullanıcı-güdümlü olduğundan MVP'de kabul edilebilir.
- **Olay zamanı:** `autoConfirmed` olayın `timestamp`'i onaya değil **tespit
  penceresinin başlangıcına** (`window.start`) ayarlanır (gerçekte içtiği an).
- **Sensör veri lag'i:** CMSensorRecorder son saniyeleri geç verir (Faz 1'le aynı
  sınır; cursor bir sonraki yenilemede kalan veriyi yakalar).
- **Arka plan kısıtı:** Sistem yenilemeyi seyrekleştirebilir → tespit en-iyi-çaba;
  kaçan olay için **manuel +1 her zaman çalışır** (graceful degradation).
- **İzin reddi (bildirim):** Bildirim reddedilirse arka plan tespiti adayları yine
  diske yazar ama kullanıcıya soramaz; pratikte özellik sessizce devre dışı kalır,
  manuel +1 ve seans çalışmaya devam eder.
- **Pending birikmesi:** Yanıtlanmayan adaylar için yaşlanma — belirli süreden
  (ör. 6 saat) eski pending'ler bir sonraki yenilemede temizlenir.

## Gizlilik ve App Store

- **Onaysız asla sayılmaz / sessiz arka plan kaydı yok:** tespit yalnızca aday
  üretir; veri ancak kullanıcı onayıyla işlenir.
- Ham pencere verisi yalnızca mevcut **eğitim verisi izniyle** (Faz 1'deki
  `ConsentProviding`) arşivlenir; negatif örnekler de aynı izne tabidir.
- Bildirim izni ayrı ve açık istenir; reddi özelliği kapatır, uygulamayı bozmaz.
- `WKApplicationRefreshBackgroundTask` özel bir entitlement gerektirmez; gerekli
  Info.plist/WatchKit arka plan ayarları uygulama planında doğrulanacaktır.
- Konumlandırma Faz 1'le aynı: **farkındalık/takip**, teşvik değil.

## Test stratejisi

TDD (önce test). Saf çekirdek Codex ile `swift test` üzerinden doğrulanır.

- **`HeuristicSmokeDetector`** — sentetik `MotionSample` dizileriyle: 0 aday
  (düz/gürültü), 1 aday (tek belirgin döngü kümesi), çok aday (ayrı kümeler),
  eşik altı → aday yok, `DetectorConfig` parametre etkisi.
- **`CandidateFilter`** — cursor'dan eski adaylar elenir; çakışan pencereler tek
  sayılır; sıralı/sırasız giriş.
- **`ConfirmationFlow.outcome`** — `smoked` → doğru kaynak/etiket/zaman; `notSmoked`
  → event nil + negatif etiket; zaman damgası pencereden alınır.
- **`NotificationBudget`** — günlük üst sınır aşımı, sessiz saat aralığı, sınır
  durumları.
- **`PendingCandidate` / `CandidateWindow`** — Codable round-trip (örnekler dahil).
- **`PendingCandidateStore`** (Data) — geçici dizin: save/all/remove, bozuk dosya
  toleransı.
- **`DetectionCursorStore`** (Data) — get/set varsayılan (hiç yazılmadığında).
- **Yalnızca cihazda (manuel checklist, burada doğrulanamaz):** arka plan yenileme
  tetiği, gerçek CMSensorRecorder verisi, bildirim teslimi + Evet/Hayır aksiyonu,
  izin diyalogları, pil etkisi.

## Bilinçli olarak OLMAYANLAR (YAGNI)

- Eğitilmiş ML modeli, CreateML/Core ML hattı — **Faz 2.2**.
- Canlı/gerçek-zamanlı tespit, `HKWorkoutSession` — bu sürümde değil (periyodik
  seçildi).
- Hibrit "şimdi izle" canlı modu — sonra değerlendirilebilir.
- İçgörü/öneri, hedef/azaltma — Faz 1'le aynı kapsam dışı.
- iPhone tarafında otomatik tespit (tespit yalnızca watch'ta; sensör orada).

## Açık uçlar (uygulama planında netleşecek)

- `WKApplicationRefreshBackgroundTask` için gerekli Info.plist / arka plan modu
  anahtarlarının tam listesi ve watchOS sürüm davranışı.
- Heuristik eşiklerin başlangıç değerleri (cihaz verisiyle kalibre edilecek;
  ilk değerler muhafazakâr/recall-öncelikli seçilecek).
- Pending aday yaşlanma süresi (başlangıç ~6 saat) ve günlük bildirim üst sınırı
  (başlangıç ~8-10/gün) — plan sırasında sabitlenecek, cihaz verisiyle ayarlanacak.
- Onboarding bildirim-izni akışının watch ↔ iPhone arasında tam yeri.
