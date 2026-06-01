# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- iPhone home-screen insights: this-week and daily-average stats, a 7-day bar chart (Swift Charts), a week-over-week trend, and a smoke-free-streak banner.
- New pure `StatsEngine` metrics: gap-filled date ranges, daily average, hourly distribution, days-since-last-event, and rolling N-day windows (12 new unit tests).

### Changed
- Redesigned the Today and History screens — card-based layout, day-grouped history with per-event source badges and proper empty states.

### Planned
- Phase 2.2: on-device Core ML detector trained on collected sessions.
- Localization (move in-app strings to a String Catalog).

## [0.1.0] - 2026-06-01

First tagged version — Phase 1 (MVP) feature-complete, with the Phase 2.1
assisted-detection groundwork in place (pending on-device verification).

### Added
- One-tap `+1` logging from the watch-face complication (WidgetKit accessory widget).
- Watch app with today's count and a large `+1` button.
- Offline-safe watch → iPhone sync over WatchConnectivity (`transferUserInfo`), with idempotent de-duplication.
- iPhone companion with a SwiftData event store as the source of truth, plus today/history stats.
- Optional accelerometer "training sessions" that archive raw motion under a `smoking` label (opt-in, revocable consent).
- Onboarding flow + Motion & notification permission handling with graceful degradation.
- Two-way consent sync across devices (`updateApplicationContext`, latest-wins).
- Phase 2.1 assisted detection: background candidate detector (`HeuristicSmokeDetector`), a notification-budgeted confirmation flow, and Yes/No answers → labelled training data.

### Engineering
- Modular architecture: `SmokeTrackerCore` (pure domain logic) and `SmokeTrackerData` (persistence) as Swift packages, consumed by the app.
- 83 unit tests (47 Core + 36 Data) run in CI on every push.

### Notes
- Distributed as a personal/development build; not yet on the App Store.
- Phase 2.1 background detection, real-sensor capture, and notification delivery are verified on a physical device only.

[Unreleased]: https://github.com/batukizmazoglu/smoke-tracker/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/batukizmazoglu/smoke-tracker/releases/tag/v0.1.0
