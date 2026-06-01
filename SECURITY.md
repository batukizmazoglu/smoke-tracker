# Security Policy

Smoke Tracker is a local-first iOS + watchOS app. It has no backend server and
does not transmit user data off-device, so the security surface is mostly the
app itself and the privacy of locally stored (and potentially sensitive) data.

## Supported versions

The project is pre-1.0 and under active development. Only the latest `main` and
the most recent release receive security fixes.

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅        |
| < 0.1   | ❌        |

## Reporting a vulnerability

Please **do not** open a public issue for security or privacy vulnerabilities.

Instead, report it privately via GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
(repository **Security** tab → **Report a vulnerability**), or email the
maintainer.

Please include: a description, steps to reproduce, the affected version/commit,
and the potential impact. You can expect an initial response within a few days.

## Scope

**In scope:** data-handling / privacy issues (e.g. raw motion data accessible
without consent), insecure local storage, or App Group container leakage.

**Out of scope:** issues that require a jailbroken device or physical access to
an already-unlocked device.
