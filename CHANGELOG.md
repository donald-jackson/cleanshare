# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Share-extension UX is no longer a gimmick.** After cleaning, the share
  sheet now shows an honest success state ("Cleaned & ready — open CleanShare
  to continue") with a brand-styled "Open CleanShare" CTA, instead of trying
  to auto-launch the host app via responder-chain selector dispatch (which
  iOS 17+ either drops outright or routes to the Files-export fallback).
  Manifests are still persisted to the App Group inbox, and tapping the CTA
  best-effort-launches the host app on a fresh user gesture — but if iOS
  drops that too, the cost is one extra tap on the CleanShare icon.
- **Foreground inbox sweep is now age-capped at 3 minutes.** A user opening
  CleanShare days after a share-extension run gets a fresh app instead of a
  stale share sheet for content they've moved on from. Recent shares (<3 min
  old) still auto-present. Older manifests age out via the existing TTL
  cleanup. `HandoffRouter.foregroundSweepMaxAge` is the knob.
- **`RootView` repainted with brand-styled buttons.** Replaces the default
  `.borderedProminent` SwiftUI buttons (flat blue text-only pills) with a
  proper visual hierarchy: a primary teal→indigo-gradient capsule for "Clean
  photos…" (the actual job), and two indigo-tinted secondary capsules for
  the demo entry points. SF Symbol leading icons (`wand.and.stars`, `photo`,
  `livephoto`). Rounded display weight on the title.

### Added

- `BrandPalette` and `CleanSharePrimaryButtonStyle` / `CleanShareSecondaryButtonStyle`
  in the `CleanShareUI` package — reusable brand-styling primitives so future
  views don't redefine the gradient or duplicate the capsule shape.
- `CleaningPhase` enum on `CleaningProgressModel` + a `.ready` success view in
  `CleaningProgressView` (gradient checkmark + "Cleaned & ready" prompt +
  primary "Open CleanShare" CTA).

### Fixed

- Share-extension handoff now fires `openURL:` **after** `completeRequest`
  dismisses the share-extension view (the iOS 17+ order requirement —
  previous releases tried it before dismissal, which iOS silently dropped).
  Manifest is persisted to the App Group inbox before dismissal, and
  `HandoffRouter.applyPendingInbox` sweeps that inbox on cold start AND on
  every transition to `.active` so the share sheet still appears even if
  iOS drops the `openURL` call entirely.
- Progress view briefly settles at 100% with a "Cleaned" label for ~300 ms
  before dismissing — visual closure instead of the extension blinking
  away mid-stream.

### Removed

- Dead handoff scaffolding: `HandOffArbiter`, `presentFilesFallback`, and
  the `UIDocumentPickerDelegate` extension on `ShareViewController` are
  gone now that the handoff no longer falls back to the Files dialog.

## [0.1.1] - 2026-06-05

### Added

- Universal Links handoff as the Apple-blessed path for the share extension to
  re-present the system share sheet via the host app.

### Fixed

- Share-extension handoff now reliably re-presents the system re-share sheet
  instead of falling back to the Files dialog.

### Changed

- Release process gains a pre-release device smoke-test recipe covering the
  Photos/WhatsApp share flows, Live Photo consent, 4K video, and network-loss
  retry.

## [0.1.0] - 2026-06-04

### Added

- Initial project scaffold: host app, share extension, and `CleanShareCore` engine package.
