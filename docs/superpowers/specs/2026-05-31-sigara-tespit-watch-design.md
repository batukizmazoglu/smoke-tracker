# Sigara/IQOS Takip — Apple Watch + iPhone (MVP Tasarımı)

**Tarih:** 2026-05-31
**Durum:** Onaylandı (brainstorming) → uygulama planına geçilecek
**Çalışma adı:** smoke-tracker (App Store adı sonra belirlenecek)

## Amaç

Apple Watch kullanıcısının gün içinde kaç sigara/IQOS içtiğini takip eden bir
uygulama. Uzun vadede sigara içme hareketini (el-ağız paterni) sensörlerden
otomatik algılamayı hedefler; MVP ise bunu yarı-otomatik + manuel kayıtla
çözer ve aynı zamanda otomatik tespit için eğitim verisi toplar.

## Hedef ve kapsam

- **Hedef seviyesi:** App Store'da yayınlanacak ciddi ürün. Doğruluk, gizlilik,
  pil ve App Store onayı kritik.
- **MVP kapsamı:** Saf takip + temel istatistik. Hedef/azaltma/bırakma desteği,
  akıllı içgörüler ve hatırlatmalar MVP'de **yok** (sonraki sürümlere bırakıldı).

## Aşamalı strateji (neden böyle)

Sigara hareketini benzer hareketlerden (yemek, içme, telefon, yüze dokunma)
ayırmak çözülebilir bir ML problemidir ama **etiketli eğitim verisi** gerektirir.
Lansmanda elde sıfır veri olur — bu yüzden otomatik tespite soğuktan başlanamaz.

| Faz | İçerik | Gerekçe |
|-----|--------|---------|
| **Faz 1 (MVP)** | Yarı-otomatik "seans" + tek dokunuşla manuel kayıt | Hemen değer üretir, watchOS-dostu, pil kontrollü, **etiketli veri toplar** |
| **Faz 2** | Arka planda otomatik tespit + "Sigara içtin mi?" onayı | Faz 1 verisiyle model eğitilir; onaylar modeli iyileştirir |
| **Faz 3** | İsteyen kullanıcı için tam pasif tespit | Doğruluk yeterince yükselince |

Bu doküman **yalnızca Faz 1 (MVP)** kapsamını tanımlar.

## Kararlar (özet)

| Konu | Karar |
|------|-------|
| Platform | Apple Watch + iPhone companion (local-first) |
| Sayım birimi | Sadece **adet** (1 seans = 1 çubuk) |
| Tür ayrımı | Yok — hepsi tek kalemde "sigara" |
| Kayıt şekli | Tek dokunuş +1 (birincil) + opsiyonel sensörlü seans (Faz 2 verisi) |
| Birincil giriş | Complication (saat kadranından tek dokunuş) |
| Dil/çatı | Swift + SwiftUI (watchOS + iOS) |
| Veri | SwiftData; tek doğruluk kaynağı iPhone |
| Senkron | WatchConnectivity (`transferUserInfo` — garantili teslim) |
| Seans kaydı | `CMSensorRecorder` (50Hz ivmeölçer, arka plan, pil dostu) |

## Mimari

İki uygulamalı, yerel-öncelikli (local-first) yapı.

```
┌─────────────────── Apple Watch ───────────────────┐
│  • Complication (kadrandan tek dokunuş → +1)       │
│  • Watch App: bugünkü sayı + büyük "+1" butonu     │
│  • Opsiyonel "Seans" modu → hareket kaydı          │
│  • Yerel kayıt (senkronlanana kadar kuyruk)        │
└───────────────────────┬───────────────────────────┘
                        │ WatchConnectivity
┌───────────────────────┴───────────────────────────┐
│                  iPhone Companion                  │
│  • Ana veri deposu (SwiftData) — source of truth   │
│  • İstatistik ekranları (gün/hafta/trend)          │
│  • Onboarding + izinler + gizlilik                 │
│  • Ham seans verisi arşivi (Faz 2 için, izinle)    │
└────────────────────────────────────────────────────┘
```

- Source of truth iPhone'dadır. Watch çevrimdışıyken yerel kuyruğa yazar,
  bağlanınca senkronlar.
- `transferUserInfo` kuyruğu, watch çevrimdışı/uyku halindeyken bile teslimi
  garanti eder.

## Bileşenler

Her bileşen tek sorumluluk taşır, iyi tanımlı arayüzle haberleşir, ayrı test
edilebilir.

### Watch tarafı
- **`QuickLogManager`** — "+1" işlemini yapar, yerel kuyruğa yazar, senkronu
  tetikler. Bağımlılık: `WatchStore` + WatchConnectivity.
- **`SessionRecorder`** — opsiyonel seans: başlat/bitir, hareket verisini
  yakalar (bkz. Veri akışı), bitince +1 + ham veri paketi üretir.
- **`WatchStore`** — watch'taki hafif yerel kayıt; senkronlanana kadar bekleyen
  olaylar.
- **`ComplicationProvider`** — kadran complication'ı; dokununca uygulamayı "+1
  niyetiyle" açar.

### iPhone tarafı
- **`EventStore`** (SwiftData) — tüm sigara olaylarının ana deposu.
  `SmokingEvent { id: UUID, timestamp: Date, source: tap|session,
  sessionDataRef: ID? }`.
- **`SyncCoordinator`** — watch'tan gelen olayları alır, çift kaydı (dedup)
  idempotent `id` ile önler.
- **`StatsEngine`** — günlük/haftalık toplamlar, basit trend. Saf fonksiyonlar
  → kolay test edilir.
- **`TrainingDataArchive`** — sensörlü seansların ham verisini "sigara"
  etiketiyle saklar (Faz 2). Kullanıcı izniyle, ayrı ve şeffaf.
- **`OnboardingFlow` + `PermissionsManager`** — izinler (Motion & Fitness,
  bildirim), gizlilik onayı.

## Veri akışı

### Tek dokunuş (+1) — birincil, en sağlam yol
1. Complication'a dokun → watch app açılır.
2. `QuickLogManager` anında yerel kuyruğa `SmokingEvent(source: tap)` yazar.
3. Ekranda "bugün: N+1" gösterilir.
4. Arka planda iPhone'a senkron; çevrimdışıysa kuyrukta bekler.
- **Hiçbir özel izin veya arka plan yürütme gerektirmez.**

### Opsiyonel seans (Faz 2'nin veri köprüsü)
1. Kullanıcı "Seans başlat" der.
2. `SessionRecorder` ~5-7 dk boyunca `CMSensorRecorder` ile ivmeölçeri 50Hz
   kaydeder (arka planda, uygulamayı uyanık tutmadan).
3. "Bitir" (veya hareketsizlikle oto-bitiş) → +1 + ham veri paketi
   `TrainingDataArchive`'a "sigara" etiketiyle gider.
- Seans tamamen opsiyoneldir; kullanıcı hiç kullanmazsa uygulama tam çalışır.

### Seans kaydı için teknik karar
- **Seçilen: `CMSensorRecorder`** — arka planda 50Hz ivmeölçer kaydı, sonradan
  toplu çekme. Uygulamayı uyanık tutmaz, pil dostu. Sınır: sadece ivmeölçer
  (jiroskop yok), eski API. MVP için yeterli ve düşük riskli.
- **Alternatif (Faz 2/3): `HKWorkoutSession`** — accel+gyro 100Hz, seans boyunca
  uygulama canlı. "Egzersiz" olarak işaretlenir, Sağlık'a workout yazar, pili
  daha çok yer. Zengin veri gerekince geçilecek.

## Hata yönetimi

- **Çift sayım / yarış durumu:** Her olay benzersiz `id` taşır; `SyncCoordinator`
  idempotenttir — aynı olay iki kez gelse tek sayılır. Complication için kısa
  debounce.
- **Çevrimdışı / senkron gecikmesi:** `transferUserInfo` kuyruğu kayıpları önler;
  watch ve iPhone toplamları "son senkron" zaman damgasıyla tutarlı gösterilir.
- **İzin reddi:** Motion izni reddedilirse seans modu kapanır ama **tek dokunuş
  +1 çalışmaya devam eder** (graceful degradation).
- **Saat/zaman dilimi:** Gün sınırı kullanıcının yerel zaman dilimine göre
  hesaplanır; gece yarısı ve DST geçişleri `StatsEngine` testlerinde ele alınır.

## Gizlilik ve App Store

- Sigara verisi hassas sağlık verisidir. **Local-first**, veri satışı yok.
- Ham seans verisi yalnızca **açık izinle** ve ayrı, şeffaf bir ekranla toplanır;
  kullanıcı istediğinde silebilir.
- App Store gizlilik etiketi + gizlilik politikası gerekli.
- **App Store kuralı:** Apple tütün **kullanımını teşvik eden** uygulamaları
  reddeder ama **takip/farkındalık/azaltma** uygulamalarına izin verir. Ürün
  "farkındalık/takip" çerçevesinde konumlandırılacak (teşvik değil).
- CoreMotion için "Motion & Fitness" kullanım açıklaması (Info.plist) gerekli.

## Test stratejisi

TDD ile gidilecek (önce test, sonra implementasyon).

- **`StatsEngine`** — saf fonksiyon; birim testler: gün sınırı, zaman dilimi,
  hafta başlangıcı, DST, boş gün edge case'leri.
- **`SyncCoordinator`** — dedup/idempotency: aynı olay iki kez, çevrimdışı
  kuyruk, sıra dışı teslim.
- **`QuickLogManager`** — izole, mock `WatchStore` ile.
- **`SessionRecorder`** — başlat/bitir/oto-bitiş durum makinesi; sensör katmanı
  mock'lanır.

## MVP'de bilinçli olarak OLMAYANLAR (YAGNI)

- Otomatik arka plan tespiti (Faz 2).
- IQOS/sigara tür ayrımı.
- Nefes sayısı / seans süresi istatistikleri.
- Hedef, azaltma, bırakma desteği, akıllı içgörüler, hatırlatmalar.
- Bulut/iCloud senkronu, web paneli.

## Açık uçlar (uygulama planında netleşecek)

- Minimum desteklenen watchOS/iOS sürümleri (SwiftData → iOS/watchOS 10+).
- Complication türleri (hangi kadran ailesi) ve Smart Stack/Action Button gibi
  ikincil giriş noktalarının ileride eklenmesi.
- Ham seans veri paketinin disk formatı ve saklama süresi.
