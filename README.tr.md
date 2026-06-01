# Smoke Tracker

> Gün içinde kaç sigara / IQOS içtiğinizi sayan bir Apple Watch + iPhone uygulaması — bugün güvenilir tek dokunuşla kayıt, yarın cihaz‑içi ML tabanlı pasif tespit.

[![CI](https://github.com/batukizmazoglu/smoke-tracker/actions/workflows/ci.yml/badge.svg)](https://github.com/batukizmazoglu/smoke-tracker/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20watchOS%2010-blue.svg)

🇬🇧 **English version: [README.md](README.md)**

---

## Neden bu proje

Sigarayı elle saymak hiç tutmaz — unutursunuz, kendinizi kandırırsınız, veri işe yaramaz. Bileğinizdeki saat zaten sigaranın el‑ağız hareketini hissediyor; asıl zor olan, bu sinyali dürüst ve gizli bir sayıya çevirmek.

Sigara içmeyi ham hareketten tespit etmek çözülebilir bir ML problemi, ama **etiketli eğitim verisi** gerektirir — ve lansman günü elde sıfır veri olur. Bu yüzden uygulama bilinçli olarak fazlara bölündü: hemen değer üreten bir şey yayınla, o kullanım sırasında daha akıllı sürümü besleyecek etiketli veriyi sessizce topla.

| Faz | Ne yapar | Durum |
|-----|----------|-------|
| **Faz 1 — MVP** | Saat complication'ından tek dokunuşla `+1` + etiketli hareket verisi toplayan opsiyonel sensörlü "seans"lar | ✅ Tamam |
| **Faz 2 — Yarı otomatik** | Arka planda aday tespiti → "Sigara mı içtin?" onayı; her cevap eğitim verisini etiketler | 🟡 Sürüyor (heuristik detektör + onay döngüsü uygulandı; cihaz‑üstü doğrulama bekliyor) |
| **Faz 3 — Pasif** | Doğruluk yeterince yükselince tamamen pasif cihaz‑içi tespit | ⬜ Planlandı |

## Özellikler

- **Tek dokunuşla kayıt** — saat kadranındaki complication'a dokun, anında `+1`. İzin veya arka plan yürütme gerektirmez; her zaman çalışır.
- **Bir bakışta içgörü** — iPhone ana ekranı bugünkü sayıyı, bu hafta ve günlük ortalama istatistiklerini, 7 günlük çubuk grafiği, haftadan haftaya trendi ve sigara‑bırakma serisi bandını gösterir. Geçmiş güne göre gruplanır; her gün için toplam ve her olay için kaynak rozeti vardır. Tüm sayılar saf, birim‑testli `StatsEngine` tarafından hesaplanır.
- **Çevrimdışı‑güvenli senkron** — saat olayları yerelde kuyruğa alır, `WatchConnectivity` (`transferUserInfo`, garantili teslim) ile iPhone'a senkronlar. Tek doğruluk kaynağı iPhone'dur.
- **Idempotent çift kayıt önleme** — her olay bir UUID taşır; aynı olay iki kez senkronlansa tek sayılır.
- **Opsiyonel eğitim seansları** — Faz‑2 modelini başlatmak için, izinle açılan ivmeölçer kaydı ham hareketi `"sigara"` etiketiyle arşivler.
- **Yarı otomatik tespit (Faz 2)** — saf, deterministik bir heuristik detektör aday önerir; bildirim‑bütçeli onay akışı Evet/Hayır cevabınızı etiketli veriye çevirir.
- **Yerel‑öncelikli & gizli** — sigara hassas sağlık verisidir. Her şey cihazda kalır; ham hareket yalnızca açık ve geri alınabilir onayla kaydedilir.

<!--
Ekran görüntüleri — docs/screenshots/ içine görselleri koyup aşağıyı açın:

| Watch complication | Bugün (Watch) | Geçmiş (iPhone) |
|---|---|---|
| ![](docs/screenshots/complication.png) | ![](docs/screenshots/watch-today.png) | ![](docs/screenshots/iphone-history.png) |
-->

## Mimari

Kod, katı ve tek yönlü bağımlılıklara sahip üç katmana ayrılmıştır. Alttaki iki katman **UI'sız ve Apple‑çatısı I/O'suz** düz Swift paketleridir; bu da domain mantığını her makinede tamamen birim‑test edilebilir kılar.

```
        ┌──────────────────────── SmokeTrackerApp ────────────────────────┐
        │  iOS uygulaması · watchOS uygulaması · watchOS Widget (compl.)   │
        │            SwiftUI ekranları + platform tutkalı (CoreMotion,     │
        │             WatchConnectivity, SwiftData, bildirimler)           │
        └───────────────┬──────────────────────────────┬──────────────────┘
                        │ bağımlı                       │ bağımlı
        ┌───────────────▼───────────────┐   ┌───────────▼──────────────────┐
        │       SmokeTrackerData         │──▶│        SmokeTrackerCore        │
        │  kalıcılık & codec'ler:        │   │  saf domain mantığı, I/O yok:  │
        │  SwiftData/dosya olay depoları,│   │  StatsEngine, SyncCoordinator, │
        │  eğitim arşivi, sync codec'ler │   │  HeuristicSmokeDetector,       │
        │                                │   │  ConfirmationFlow, bütçeler…   │
        └────────────────────────────────┘   └────────────────────────────────┘
```

| Modül | Tür | Sorumluluk |
|-------|-----|------------|
| `SmokeTrackerCore` | Swift paketi (kütüphane) | Saf, deterministik domain mantığı — istatistik, senkron çift‑kayıt önleme, heuristik detektör, onay akışı, bildirim bütçeleri. Yalnızca Foundation'a bağımlı. |
| `SmokeTrackerData` | Swift paketi (kütüphane) | Kalıcılık ve serileştirme — SwiftData/dosya tabanlı olay depoları, eğitim‑verisi arşivi, sync/onay codec'leri, paylaşılan App Group konteyneri. |
| `SmokeTrackerApp` | Xcode projesi (XcodeGen) | Yayınlanacak uygulamalar: iPhone companion, watchOS uygulaması ve watchOS Widget complication'ı. SwiftUI + paketlerin uzak durduğu platform entegrasyonları. |

Bağımlılık kuralı: **App → Data → Core**. Core diğerlerini asla import etmez; bu, bolca test edilmiş mantığı UI ve OS API'lerinden izole tutar.

### Üst düzey veri akışı

```
Watch complication ──dokunuş──▶ QuickLogManager ──▶ yerel kuyruk ──WatchConnectivity──▶ iPhone
                                                                                          │
                                                                       SyncCoordinator (idempotent)
                                                                                          │
                                                                                SwiftData olay deposu
                                                                                          │
                                                                       StatsEngine ──▶ Bugün / Geçmiş
```

## Başlangıç

### Gereksinimler

- **Xcode 16+** olan macOS (Swift 6 toolchain)
- App projesini üretmek için [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Test paketlerini çalıştır (Xcode projesi gerekmez)

Domain ve kalıcılık mantığı, düz SwiftPM paketleri olarak çalışan **95 test** ile kaplıdır:

```bash
# Saf domain mantığı — 59 test
cd SmokeTrackerCore && swift test

# Kalıcılık & codec'ler — 36 test
cd SmokeTrackerData && swift test
```

### Uygulamaları derle & çalıştır

Xcode projesi [`SmokeTrackerApp/project.yml`](SmokeTrackerApp/project.yml) dosyasından **üretilir** ve commit'lenmez (böylece repo temiz ve merge‑çakışmasız kalır):

```bash
cd SmokeTrackerApp
xcodegen generate          # SmokeTracker.xcodeproj üretir
open SmokeTracker.xcodeproj
```

Ardından Xcode'da **SmokeTracker** scheme'ini seçip bir iPhone + eşleştirilmiş Apple Watch'ta (veya simülatörlerde) çalıştırın.

> **Kendi hesabınızla derleme:** `project.yml` bir `DEVELOPMENT_TEAM` sabitler. Kendi Apple ID'nizle derlemek için bu değeri kendi Team ID'nizle değiştirin (Xcode → Settings → Accounts) veya boşaltıp Xcode'un otomatik imzalamayı yönetmesine izin verin.

## Proje durumu & yol haritası

Bu, çöpe atılacak bir demo değil — App Store hedefli, aktif geliştirilen gerçek bir üründür.

- ✅ **Faz 1 (MVP):** tek dokunuşla kayıt, çevrimdışı‑güvenli senkron, istatistik, opsiyonel eğitim seansları, onboarding & onay.
- 🟡 **Faz 2.1:** arka planda aday tespiti + onay döngüsü (uygulandı; cihaz‑üstü doğrulama sürüyor).
- ⬜ **Faz 2.2:** toplanan seanslarla eğitilmiş Core ML modeli.
- ⬜ **Faz 3:** opsiyonel, tamamen pasif tespit.

Tasarım ve uygulama dokümanları [`docs/`](docs/) altında (Türkçe) yer alır ve her fazın ardındaki gerekçeyi belgeler.

## Gizlilik

Sigara verisi hassas sağlık bilgisidir ve öyle ele alınır:

- **Yerel‑öncelikli.** Doğruluk kaynağı iPhone'dur; sunucu yok, veri satışı yok.
- **Açık onay.** Eğitim için ham hareket yalnızca opt‑in sonrası, ayrı ve şeffaf bir ekranda kaydedilir ve kullanıcı tarafından silinebilir.
- Apple'ın tütün kullanımını teşvik etmeyen **farkındalık / takip / azaltma** uygulaması kurallarına uygun tasarlandı.

## Teknik öne çıkanlar

İncelemeciler için mühendislik sinyali:

- Katı eşzamanlılıkla **Swift 6**; `Sendable` domain tipleri.
- **Test‑öncelikli geliştirme (TDD)** — mantık önce testle yazıldı, 95 geçen test, detektör ve istatistik için deterministik saf fonksiyonlar.
- **Protokol‑odaklı bağımlılık enjeksiyonu** (`PendingCandidateStoring`, `SmokeDetecting`, …) Core'u I/O'dan uzak ve kolay mock'lanır tutar.
- Yalnızca gelenekle değil, paket grafiğiyle **dayatılan temiz modüler sınırlar**.
- `.xcodeproj`'in diff'leri kirletmemesi için **üretilen proje** (XcodeGen).
- **Conventional commits** ve her push'ta yeşil CI kapısı.

## Katkı

Katkılar açıktır — geliştirme akışı, kurallar ve CI'ın çalıştırdığı kontroller için [CONTRIBUTING.md](CONTRIBUTING.md) dosyasına bakın.

## Lisans

[MIT](LICENSE) © 2026 Batu Kızmazoğlu
