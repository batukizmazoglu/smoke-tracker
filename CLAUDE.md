# CLAUDE.md

Guidance for Claude Code (and any AI assistant) working in this repository.

## Project goal

Smoke Tracker is a **public, open‑source** Apple Watch + iPhone app that tracks
cigarette / IQOS intake. This repository is held to a deliberately high bar
because it serves two audiences at once:

1. **The community** — anyone should be able to land on the repo, understand
   what it does and how it's built in a few minutes, build it, run the tests,
   and contribute. Keep the README, CONTRIBUTING, and design docs accurate and
   welcoming.
2. **Hiring reviewers (CTOs / engineers)** — the repo is part of a professional
   portfolio. Code quality, clean git history, sensible architecture, real test
   coverage, and tidy GitHub hygiene are the product as much as the app is.

**Every change should leave the repo more understandable, more contributable,
and more impressive — never less.** When in doubt, optimize for clarity and for
the next reader.

Concretely, that means:

- Keep the README (EN) and `README.tr.md` (TR) in sync and current.
- Keep CI green; do not merge red.
- Maintain a clean, conventional‑commit git history; no noisy/junk commits.
- Never commit build artifacts, generated projects, secrets, or personal
  signing config (see `.gitignore`).
- Prefer the smallest change that fully solves the problem; explain the "why"
  in commit messages and docs.

## Architecture

Three layers, strictly one‑directional dependencies: **App → Data → Core**.

| Module | Type | Responsibility |
|--------|------|----------------|
| `SmokeTrackerCore` | Swift package | Pure, deterministic domain logic — `StatsEngine`, `SyncCoordinator`, `HeuristicSmokeDetector`, `ConfirmationFlow`, `NotificationBudget`, etc. **Foundation only, no I/O, no UI.** |
| `SmokeTrackerData` | Swift package | Persistence & serialization — SwiftData/file event stores, training‑data archive, sync/consent codecs, shared App Group container. Depends on Core. |
| `SmokeTrackerApp` | Xcode project (XcodeGen) | iOS app, watchOS app, watchOS Widget. SwiftUI + platform glue (CoreMotion, WatchConnectivity, SwiftData, notifications). Generated from `project.yml`. |

**Layering rules:**
- New logic that doesn't need OS frameworks goes in `Core` and must be unit‑tested.
- Persistence/serialization goes in `Data`, behind protocols defined in `Core`
  where it makes sense (e.g. `PendingCandidateStoring`, `SmokeDetecting`).
- `Core` must never import `Data` or any Apple framework beyond Foundation.

## Commands

```bash
# Run the domain logic tests (59 tests)
cd SmokeTrackerCore && swift test

# Run the persistence tests (36 tests)
cd SmokeTrackerData && swift test

# Generate & open the app project
cd SmokeTrackerApp && xcodegen generate && open SmokeTracker.xcodeproj
```

Toolchain: **Swift 6 / Xcode 16+**, targets **iOS 17 / watchOS 10**.

## Conventions

- **Test‑driven.** Write the test first for Core/Data logic. Keep all 95 tests
  green; add tests with every logic change.
- **Conventional Commits**, scopes `core` / `data` / `watch` / `ios`
  (e.g. `feat(watch): …`, `fix(data): …`). Commit messages in this repo are
  written in Turkish — follow the existing style.
- **Comments** in the existing code are in Turkish; match the file you edit.
- **Bilingual docs:** user‑facing docs are EN (`README.md`) + TR
  (`README.tr.md`); design specs in `docs/` are Turkish.
- **Privacy first:** smoking is sensitive health data. Local‑first, explicit
  revocable consent for any raw‑motion capture, no data sale. Don't add network
  calls, analytics, or telemetry without an explicit decision.
- **Committing:** only commit/push when the user asks; never push to the public
  remote without confirmation.

## Status & roadmap

- ✅ Phase 1 (MVP): one‑tap logging, offline‑safe sync, stats, optional training
  sessions, onboarding & consent.
- 🟡 Phase 2.1: background candidate detection + confirmation loop (implemented;
  on‑device verification pending).
- ⬜ Phase 2.2: Core ML model trained on collected sessions.
- ⬜ Phase 3: opt‑in fully passive detection.

Design and implementation docs live under `docs/superpowers/{specs,plans}/`
(Turkish) and explain the reasoning behind each phase. Read the relevant spec
before changing behavior it describes.
