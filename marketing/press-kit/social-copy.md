<!-- Copy-paste-ready launch posts. Substitute every <placeholder>, the github.com/<placeholder>/cleanshare URL, and the App Store link before posting. Sequence and timing live in PLAN.md §14.4. -->

# CleanShare — Launch Social Copy

## Mastodon

Just shipped CleanShare: a free, open-source iOS app that strips hidden metadata from your photos and videos before you share them. Pick a photo, tap Share, choose CleanShare, and it hands you a cleaned copy — no GPS, no EXIF, no camera make/model, no Apple MakerNote. Nothing leaves your device, and CI fails the build if the app makes a single network request. MIT-licensed and fully auditable. Source: github.com/<placeholder>/cleanshare — App Store: <App Store URL>

#iOS #privacy #opensource

## Hacker News (Show HN)

**Title:** Show HN: CleanShare – iOS app that strips photo metadata before sharing (MIT)

I built CleanShare because every photo and video you send carries more than the picture: GPS coordinates, camera make and model, timestamps, the Apple MakerNote, IPTC/XMP blocks, and embedded thumbnails all ride along silently. Most sharing flows do nothing about it, and most people never see it. CleanShare inserts itself into the iOS share sheet — pick a photo, tap Share, choose CleanShare, and it re-presents the system share sheet with a cleaned copy ready for WhatsApp, Messages, Instagram, or anywhere else. Your originals are never touched, and nothing leaves the device.

A few technical notes that might interest this crowd:

- **Video uses AVAssetWriter passthrough** (`outputSettings: nil` plus a `sourceFormatHint`) so there's no re-encode — sample buffers are copied losslessly while the metadata and timed-metadata tracks are dropped. Near-realtime, zero quality loss.
- **Images go through ImageIO with a deliberately safe pattern:** `CGImageDestinationAddImage(dest, cgImage, props)` with explicit `kCFNull` for each metadata dictionary, never `CGImageDestinationAddImageFromSource` (which silently copies the source metadata back in). A custom SwiftLint rule fails the build if anyone reintroduces the dangerous call.
- **Swift 6 with strict concurrency** (`SWIFT_STRICT_CONCURRENCY = complete`) across the engine, which is a standalone Swift package shared by both the app and the ~120 MB-capped share extension.
- **The privacy guarantees are enforced by CI**, not just documented. A metadata regression test cleans known-dirty fixtures and asserts (via exiftool) that no EXIF/GPS/MakerNote group survives. A separate **network-silence test** asserts the app and extension make zero requests — the build fails on a single one.

Zero third-party runtime dependencies — just Foundation, ImageIO, AVFoundation, SwiftUI, and UIKit. App Store privacy label is "Data Not Collected." Source (MIT): github.com/<placeholder>/cleanshare — App Store: <App Store URL>. Happy to answer questions about the metadata-stripping internals.

## r/iOSProgramming

**Title:** CleanShare: an open-source share-extension that strips photo/video metadata (Swift 6, AVAssetWriter passthrough, ImageIO)

CleanShare is a free, MIT-licensed iOS app I built as a share-extension that strips EXIF/GPS/MakerNote/XMP from photos and timed-metadata tracks from video. On the engineering side: the cleaning engine is a standalone Swift package compiled under Swift 6 strict concurrency and shared between the host app and the ~120 MB-capped extension. Video cleaning uses AVAssetWriter passthrough (`outputSettings: nil` + `sourceFormatHint`) for a lossless, near-realtime copy with no re-encode; images use ImageIO's `CGImageDestinationAddImage` with explicit `kCFNull` dictionaries rather than `...AddImageFromSource`, with a custom SwiftLint rule guarding against regressions. The extension can't present a `UIActivityViewController`, so it hands off to the host app via a `cleanshare://handoff` URL. Code and architecture notes: github.com/<placeholder>/cleanshare — App Store: <App Store URL>

## r/privacy

**Title:** CleanShare: a free, open-source iOS app that removes the hidden location and device data from photos before you share them

If you've ever sent a photo over a messaging app, you've probably also sent your GPS coordinates, your exact capture timestamp, your camera/phone make and model, and the Apple MakerNote — all embedded in the file and readable by whoever receives it. CleanShare is a free, MIT-licensed iOS app that strips that data from inside the share sheet before the file ever reaches the destination app. The threat model is "data leaving your phone": nothing is uploaded, there are no accounts or identifiers, there's no analytics or telemetry that leaves the device, and the app has no network access at all — that last point is verified by a CI test that fails the build if the app makes a single request. The whole thing is open source and auditable, with an App Store privacy label of "Data Not Collected." Source: github.com/<placeholder>/cleanshare — App Store: <App Store URL>

## Twitter / X

🛡️ CleanShare is live: free, open-source iOS app that strips GPS, EXIF & camera metadata from photos & videos in the share sheet. Nothing leaves your phone — CI fails if it makes one network call. MIT.

App Store: <App Store URL>
Source: github.com/<placeholder>/cleanshare
