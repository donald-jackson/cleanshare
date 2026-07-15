<!-- Launch-day one-pager. Fill the <placeholder> lines before distribution. -->

**FOR IMMEDIATE RELEASE — <release date>**

# CleanShare: a free, open-source iOS app that strips hidden metadata from photos and videos before you share them

Every photo and video you send carries more than the picture. EXIF tags, GPS coordinates, your camera make and model, timestamps, and the Apple MakerNote ride along silently — readable by any app or recipient you send the file to. Most people never see this data, and most sharing flows do nothing to remove it.

CleanShare fixes that from inside the iOS share sheet. Pick a photo, tap Share, choose CleanShare, and it re-presents the system share sheet with a cleaned copy — ready for WhatsApp, Messages, Instagram, or anywhere else. Your originals are never touched, and nothing leaves your device. The app is free, open source under the MIT license, and its privacy guarantees are verified by CI on every commit.

**Key features:**

- Removes EXIF, GPS, the Apple MakerNote, IPTC and XMP blocks, embedded thumbnails, QuickTime/movie metadata, and timed-metadata tracks from video.
- Preserves only what's needed to render correctly — orientation and the embedded color profile — by default; everything else is stripped.
- Live Photo modes let you keep the pairing, flatten to a still, or strip the motion component, with your choice remembered.
- Handles common still and video formats including HEIC, JPEG, PNG, and HEVC/H.264, using lossless video passthrough so there's no re-encoding or quality loss.
- Universal app for both iPhone and iPad.
- Requires iOS 17 or later.

**Privacy posture:**

- No accounts, no sign-in, no identifiers ever persisted.
- No analytics or telemetry that leaves the device (optional MetricKit diagnostics stay on-device, opt-in).
- No network access at all — verified by CI on every commit, which fails the build if the app makes a single request.
- Ships with an App Store privacy label of "Data Not Collected."
- Fully MIT-licensed, auditable source: https://github.com/donald-jackson/cleanshare

**Pricing:** Free, no in-app purchases.

**Contact:** <name>, <email>
**Press kit:** <press kit URL>
**App Store:** <App Store URL>

---

About the maintainer: see maintainer-bio.md
