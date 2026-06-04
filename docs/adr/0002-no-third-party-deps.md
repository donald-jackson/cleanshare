# 2. No third-party runtime dependencies

- Status: Accepted
- Date: 2026-06-04

## Context and Problem Statement

CleanShare's entire value proposition is that it makes a verifiable privacy
promise: it strips identifying metadata from media and collects nothing about
its users ("Data Not Collected" across every App Store privacy category). That
promise is only credible if it is *auditable*. Every third-party runtime
dependency is code we do not control, a binary blob a reviewer cannot easily
read, and an additional supply-chain entry point through which tracking,
network activity, or a future malicious update could enter the app without our
intent. For a privacy tool, the cost of a single compromised or
quietly-data-harvesting SDK is the entire trust of the product.

The question is therefore not "which dependencies should we add?" but "should we
admit any third-party runtime code at all?"

## Decision

CleanShare ships with **zero third-party runtime dependencies**. The allowed
universe is the first-party Apple framework stack only:

- Foundation, ImageIO, CoreGraphics, AVFoundation, CoreMedia,
  UniformTypeIdentifiers, PhotosUI, SwiftUI, UIKit.

No third-party SDK is permitted for any purpose — not analytics, not
crash reporting, not networking, not image/video decoding, not UI helpers.
Specifically:

- **No bundled HTTP client.** CleanShare makes no network calls at all (the
  on-device-only design means there is nothing to talk to), so there is nothing
  for an HTTP library to do.
- **No bundled image/video decoders.** ImageIO + CoreGraphics + AVFoundation
  already decode, re-encode, and sanitize every format we support. A
  third-party codec would add attack surface for no capability we lack.
- **No bundled crash reporter.** MetricKit (opt-in, on-device, manual export)
  covers diagnostics without shipping a vendor SDK that phones home. See the
  forthcoming ADR-0004 on on-device-only telemetry.

This rule applies to *runtime* code that ships in the app and extension. It does
**not** restrict developer-only / build-time tooling that never enters the
shipped binary (XcodeGen, SwiftLint, SwiftFormat, xcbeautify, Fastlane, etc.).

Adding any future runtime dependency requires a new superseding ADR that
explicitly justifies the exception.

## Enforcement

This decision is mechanically enforced, not merely documented:

- `scripts/check-no-trackers.sh` scans both the source tree and the built
  `.app` binary for forbidden analytics / crash-reporting / ad-attribution SDK
  symbols (Firebase, Mixpanel, Amplitude, Sentry, Bugsnag, Crashlytics, the
  Facebook SDKs, AppsFlyer, Branch) and fails the build on any match. It runs in
  CI as the privacy gate.
- The absence of a package manifest declaring external products (no SPM/CocoaPods/
  Carthage runtime entries) keeps the dependency graph empty by construction.

## Consequences

- **Positive:** the shipped app is fully auditable from first-party source; a
  reviewer can reason about every line of code that runs on a user's device.
- **Positive:** the supply-chain attack surface is reduced to Apple's own SDKs,
  which the platform already trusts and updates.
- **Positive:** the "Data Not Collected" claim is defensible because there is no
  third-party code that *could* collect data.
- **Negative:** we must implement, or do without, any capability a popular SDK
  would otherwise provide. In practice the Apple framework stack covers
  everything CleanShare needs, so this cost has been low.
- **Negative:** crash/diagnostics ergonomics are weaker than a hosted crash
  reporter would offer; we accept this in exchange for the privacy guarantee.

## References

- PLAN.md §15 (zero third-party dependency posture)
- PLAN.md §18 (telemetry: MetricKit, opt-in, on-device only)
- `scripts/check-no-trackers.sh` — the CI enforcement mechanism
- [[0001-record-architecture-decisions]]
- ADR-0004 (on-device-only telemetry) — the related decision on diagnostics
