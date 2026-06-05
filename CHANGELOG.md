# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
