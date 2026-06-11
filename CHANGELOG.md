# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Share extension now hands off via a local notification, not an in-extension
  CTA.** After cleaning, the extension flashes a compact "Cleaned" success
  state for ~800 ms, posts a `UNNotificationRequest` carrying the job token
  in `userInfo`, then calls `completeRequest` so the share-sheet window
  dismisses on its own. Tapping the notification opens CleanShare and the
  notification-center delegate routes the token straight into
  `HandoffRouter.handle`, which presents the system share sheet. The
  previous "Open CleanShare" CTA inside the extension never worked
  reliably on iOS 17+ and the headline / button labels truncated badly on
  iPhone 17 Pro Max (where the share-extension window is narrower than a
  full-width sheet) — both problems are now moot because the extension
  dismisses itself.
- **Notification permission is now gated behind an explainer page** in the
  onboarding flow instead of firing a cold system prompt at first launch.
  `OnboardingView` gains a fourth page ("One quick step") that tells the user
  CleanShare sends one notification per share and is only ever used for
  sharing — then the user taps **Allow notifications** to trigger the system
  prompt. Granting completes onboarding; denying flips the same page into a
  follow-up state ("Notifications are turned off … please enable them in
  Settings to continue") with an **Open Settings** deep link, and a
  `scenePhase`-based re-check finishes onboarding automatically when the
  user returns from Settings with notifications enabled. The host app no
  longer auto-requests authorization in `CleanShareNotificationCenter.attach`,
  and the privacy page's CTA changes from "Get started" to "Continue".
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

- **"Inspect a photo" feature.** New secondary CTA on `RootView` that opens
  a single-select PHPicker; the chosen file is hardlinked into a fresh
  workspace job and presented in a `MetadataInspectionView` sheet that
  shows the actual identifying values (decoded GPS coordinates, camera
  make/model, lens serial, capture date, MakerNote summary, XMP/IPTC/
  Photoshop fields, etc.) grouped by category with severity dots — red
  for high-impact fields, amber for medium, indigo for low. Each row is
  user-readable, not a raw key dump. A "Clean and share" CTA at the
  bottom runs the file through the regular cleaning pipeline and presents
  the system share sheet, so the user can go from "here's what's hiding"
  to "here's the cleaned version, ready to send" in one tap. Video files
  (MP4/MOV) are inspected via `AVMetadataItem` (location, creation date,
  make/model/software, Live Photo content identifier, timed-metadata
  tracks).
- `MetadataInspector` + `MetadataInspection` / `MetadataField` /
  `MetadataCategory` / `MetadataSeverity` in `CleanShareCore` — engine
  side of the new feature. Read-only counterpart to `MetadataAuditor`:
  the auditor flags raw key names that *survived* cleaning, the
  inspector decodes raw values that *would leak* if you didn't clean.
- `MetadataInspectionView` in `CleanShareUI` — sheet UI with loading,
  loaded, empty-state, and error states.
- `BrandPalette` and `CleanSharePrimaryButtonStyle` / `CleanShareSecondaryButtonStyle`
  in the `CleanShareUI` package — reusable brand-styling primitives so future
  views don't redefine the gradient or duplicate the capsule shape.
- `CleaningPhase` enum on `CleaningProgressModel` + a `.ready` success view in
  `CleaningProgressView` (gradient checkmark + brief "Cleaned" confirmation
  before the extension dismisses).
- `CleanShareNotificationCenter` + `AppDelegate` in the host app — registers
  as `UNUserNotificationCenter.delegate` early enough to catch cold-launch
  notification taps, buffers the token if the coordinator isn't attached yet,
  and replays it on attach. Suppresses the banner when the app is in the
  foreground (the share sheet is presented instead).
- `URL.handoffNotificationCategory` / `URL.handoffNotificationTokenKey` in
  `CleanShareCore` — single source of truth for the identifier strings the
  extension stamps into a `UNNotificationRequest` and the host reads from the
  tap response.

### Fixed

- **"Keep location (GPS)" and "Keep camera make & model" Settings toggles
  were silently dead.** The property sanitizer `kCFNull`'d every sensitive
  ImageIO dictionary on the way out but only re-added orientation and
  `DateTimeOriginal` — so flipping either toggle in Settings had no effect
  on the cleaned output. Reported by a user who turned on Keep GPS,
  cleaned via Inspect → Clean and share, and got a stripped output.
  Sanitizer now re-attaches the GPS dictionary verbatim when `keepGPS`,
  and a `{Make, Model}`-subset TIFF dict when `keepCameraMakeModel`.
  Regression covered by `PreferenceAddBackTests`.
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
