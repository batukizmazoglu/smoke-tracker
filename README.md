# Smoke Tracker

> An Apple Watch + iPhone app that tracks how many cigarettes / IQOS sticks you smoke a day — starting with reliable one-tap logging today, and building toward on‑device, ML‑based passive detection tomorrow.

[![CI](https://github.com/batukizmazoglu/smoke-tracker/actions/workflows/ci.yml/badge.svg)](https://github.com/batukizmazoglu/smoke-tracker/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20watchOS%2010-blue.svg)

🇹🇷 **Türkçe sürüm: [README.tr.md](README.tr.md)**

---

## Why this project

Counting cigarettes by hand never lasts — you forget, you lie to yourself, the data is useless. The smartwatch on your wrist already feels the hand‑to‑mouth motion of smoking; the hard part is turning that signal into an honest, private number.

Detecting smoking from raw motion is a solvable ML problem, but it needs **labelled training data** — and on launch day there is none. So the app is built in deliberate phases: ship something useful immediately, and have that usage quietly collect the labelled data that powers the smarter version later.

| Phase | What it does | Status |
|------|--------------|--------|
| **Phase 1 — MVP** | One‑tap `+1` logging from a watch complication + optional sensor "sessions" that collect labelled motion data | ✅ Done |
| **Phase 2 — Assisted** | Background candidate detection → "Did you just smoke?" confirmation; every answer labels training data | 🟡 In progress (heuristic detector + confirmation loop implemented; on‑device verification pending) |
| **Phase 3 — Passive** | Fully passive on‑device detection once accuracy is high enough | ⬜ Planned |

## Features

- **One‑tap logging** — tap the watch face complication, get an instant `+1`. No permissions, no background execution required; it always works.
- **At‑a‑glance insights** — the iPhone home screen shows today's count, this‑week and daily‑average stats, a 7‑day bar chart, a week‑over‑week trend, and a smoke‑free‑streak banner. History is grouped by day with per‑day totals and a per‑event source badge. Every number is computed by the pure, unit‑tested `StatsEngine`.
- **Offline‑safe sync** — the watch queues events locally and syncs to the iPhone over `WatchConnectivity` (`transferUserInfo`, guaranteed delivery). The iPhone is the single source of truth.
- **Idempotent de‑duplication** — every event carries a UUID; syncing the same event twice still counts once.
- **Optional training sessions** — opt‑in accelerometer recording that archives raw motion under a `"smoking"` label to bootstrap the Phase‑2 model.
- **Assisted detection (Phase 2)** — a pure, deterministic heuristic detector proposes candidates; a notification‑budgeted confirmation flow turns your Yes/No into labelled data.
- **Local‑first & private** — smoking is sensitive health data. Everything stays on device; raw motion is only ever captured with explicit, revocable consent.

<!--
Screenshots — drop images into docs/screenshots/ and uncomment:

| Watch complication | Today (Watch) | History (iPhone) |
|---|---|---|
| ![](docs/screenshots/complication.png) | ![](docs/screenshots/watch-today.png) | ![](docs/screenshots/iphone-history.png) |
-->

## Architecture

The codebase is split into three layers with strict, one‑directional dependencies. The two lower layers are plain Swift packages with **no UI and no Apple‑framework I/O**, which makes the domain logic fully unit‑testable on any machine.

```
        ┌──────────────────────── SmokeTrackerApp ────────────────────────┐
        │   iOS app   ·   watchOS app   ·   watchOS Widget (complication)  │
        │            SwiftUI views + platform glue (CoreMotion,            │
        │              WatchConnectivity, SwiftData, notifications)        │
        └───────────────┬──────────────────────────────┬──────────────────┘
                        │ depends on                    │ depends on
        ┌───────────────▼───────────────┐   ┌───────────▼──────────────────┐
        │       SmokeTrackerData         │──▶│        SmokeTrackerCore        │
        │  persistence & codecs:         │   │  pure domain logic, no I/O:    │
        │  SwiftData/file event stores,  │   │  StatsEngine, SyncCoordinator, │
        │  training archive, sync codecs │   │  HeuristicSmokeDetector,       │
        │                                │   │  ConfirmationFlow, budgets…    │
        └────────────────────────────────┘   └────────────────────────────────┘
```

| Module | Type | Responsibility |
|--------|------|----------------|
| `SmokeTrackerCore` | Swift package (library) | Pure, deterministic domain logic — stats, sync de‑dup, the heuristic detector, confirmation flow, notification budgets. Depends only on Foundation. |
| `SmokeTrackerData` | Swift package (library) | Persistence and serialization — SwiftData/file‑backed event stores, the training‑data archive, sync/consent codecs, shared App Group container. |
| `SmokeTrackerApp` | Xcode project (XcodeGen) | The shippable apps: iOS companion, watchOS app, and the watchOS Widget complication. SwiftUI + the platform integrations the packages stay free of. |

Dependency rule: **App → Data → Core**. Core never imports the others; this keeps the heavily‑tested logic isolated from UI and OS APIs.

### High‑level data flow

```
Watch complication ──tap──▶ QuickLogManager ──▶ local queue ──WatchConnectivity──▶ iPhone
                                                                                     │
                                                                  SyncCoordinator (idempotent)
                                                                                     │
                                                                            SwiftData event store
                                                                                     │
                                                                       StatsEngine ──▶ Today / History
```

## Getting started

### Prerequisites

- macOS with **Xcode 16+** (Swift 6 toolchain)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the app project: `brew install xcodegen`

### Run the test suites (no Xcode project needed)

The domain and persistence logic is covered by **95 tests** that run as plain SwiftPM packages:

```bash
# Pure domain logic — 59 tests
cd SmokeTrackerCore && swift test

# Persistence & codecs — 36 tests
cd SmokeTrackerData && swift test
```

### Build & run the apps

The Xcode project is **generated** from [`SmokeTrackerApp/project.yml`](SmokeTrackerApp/project.yml) and is not committed (so the repo stays clean and merge‑conflict‑free):

```bash
cd SmokeTrackerApp
xcodegen generate          # produces SmokeTracker.xcodeproj
open SmokeTracker.xcodeproj
```

Then in Xcode select the **SmokeTracker** scheme and run on an iPhone + paired Apple Watch (or simulators).

> **Building on your own account:** `project.yml` pins a `DEVELOPMENT_TEAM`. To build under your own Apple ID, change that value to your Team ID (Xcode → Settings → Accounts) or clear it and let Xcode manage automatic signing.

## Project status & roadmap

This is an actively developed, real product intended for the App Store — not a throwaway demo.

- ✅ **Phase 1 (MVP):** one‑tap logging, offline‑safe sync, stats, optional training sessions, onboarding & consent.
- 🟡 **Phase 2.1:** background candidate detection + confirmation loop (implemented; on‑device verification in progress).
- ⬜ **Phase 2.2:** Core ML model trained on collected sessions.
- ⬜ **Phase 3:** opt‑in fully passive detection.

Design and implementation documents live under [`docs/`](docs/) (in Turkish) and capture the reasoning behind each phase.

## Privacy

Smoking data is sensitive health information and is treated as such:

- **Local‑first.** The iPhone is the source of truth; there is no server and no data sale.
- **Explicit consent.** Raw motion for training is only captured after opt‑in, on a separate transparent screen, and can be deleted by the user.
- Designed to fit Apple's App Store rules for **awareness / tracking / reduction** apps (not promotion of tobacco use).

## Tech highlights

For reviewers skimming for engineering signal:

- **Swift 6** with strict concurrency; `Sendable` domain types.
- **Test‑driven development** — logic written test‑first, 95 passing tests, deterministic pure functions for the detector and stats.
- **Protocol‑oriented dependency injection** (`PendingCandidateStoring`, `SmokeDetecting`, …) keeps Core free of I/O and trivially mockable.
- **Clean modular boundaries** enforced by the package graph, not just convention.
- **Generated project** (XcodeGen) so the `.xcodeproj` never pollutes diffs.
- **Conventional commits** and a green CI gate on every push.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow, conventions, and how to run the checks CI runs.

## License

[MIT](LICENSE) © 2026 Batu Kızmazoğlu
