# Contributing to Smoke Tracker

Thanks for your interest! This guide explains how the project is structured, how to run the checks that CI runs, and the conventions to follow so your change can be merged smoothly.

> 🇹🇷 Türkçe katkıda bulunuyorsanız PR açıklamalarınızı ve issue'ları Türkçe yazabilirsiniz; commit mesajları için aşağıdaki conventional‑commits kuralı geçerlidir.

## Project layout

```
SmokeTrackerCore/   Pure domain logic (Swift package, no I/O) — the most heavily tested layer
SmokeTrackerData/   Persistence & codecs (Swift package, depends on Core)
SmokeTrackerApp/    iOS + watchOS apps & Widget (Xcode project generated from project.yml)
docs/               Design specs & implementation plans (Turkish)
```

Dependency rule: **App → Data → Core**. Never add an import that points the other way. New domain logic that does not need OS frameworks belongs in `SmokeTrackerCore`.

## Prerequisites

- macOS with **Xcode 16+** (Swift 6 toolchain)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Development workflow

1. **Fork & branch.** Create a topic branch from `main` (e.g. `feat/weekly-stats`, `fix/dedup-race`).
2. **Write the test first.** This project is built test‑first; logic changes in Core/Data should come with tests. See existing tests for the style (Swift Testing / XCTest).
3. **Run the suites locally** before pushing:
   ```bash
   cd SmokeTrackerCore && swift test
   cd SmokeTrackerData && swift test
   ```
   Both must be green. CI runs exactly these.
4. **For app changes,** regenerate the project and build in Xcode:
   ```bash
   cd SmokeTrackerApp && xcodegen generate && open SmokeTracker.xcodeproj
   ```
5. **Open a PR** against `main`. Fill in the PR template, link any related issue, and make sure CI is green.

## Conventions

- **Commits follow [Conventional Commits](https://www.conventionalcommits.org/):** `feat(scope): …`, `fix(scope): …`, `test(scope): …`, `refactor(scope): …`, `chore(scope): …`. Scopes used here include `core`, `data`, `watch`, `ios`. Keep each commit focused.
- **Keep generated/build artifacts out of git.** Never commit `SmokeTracker.xcodeproj`, `.build/`, `DerivedData/`, or `.DS_Store` (they are git‑ignored).
- **Don't commit secrets or personal signing config.** If you change signing to build locally, do not commit your `DEVELOPMENT_TEAM` change.
- **Match the surrounding style.** Code comments in this repo are currently in Turkish; follow the local convention of the file you edit.
- **Respect the layering.** Pure logic → `Core`; persistence/serialization → `Data`; UI/OS glue → `App`.

## What CI checks

On every push and pull request, [GitHub Actions](.github/workflows/ci.yml) runs `swift test` for both packages on macOS and validates that `xcodegen generate` succeeds. A PR should not be merged unless CI is green.

## Reporting bugs & requesting features

Use the issue templates (Bug report / Feature request). For bugs, include the device/OS, steps to reproduce, and what you expected versus what happened.

## Releases

Releases are cut manually with a semantic version tag and GitHub's built-in
release notes:

```bash
gh release create vX.Y.Z --generate-notes
```

Notes are grouped by PR label via [`.github/release.yml`](.github/release.yml).
Update [`CHANGELOG.md`](CHANGELOG.md) in the same change.

## Code of conduct

Be respectful and constructive. We follow the spirit of the [Contributor Covenant](https://www.contributor-covenant.org/).
