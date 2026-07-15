<!-- Source of truth for the App Store listing copy. -->
<!-- The plain .txt files under fastlane/metadata/en-US/ are extracts of this file. -->
<!-- Edit here first, then regenerate name.txt / subtitle.txt / description.txt to match. -->

## Name

CleanShare

## Subtitle (≤30 chars)

Strip metadata before sharing

## Description

CleanShare strips identifying metadata from your photos and videos before you send them. It lives in the iOS share sheet: pick a photo, tap Share, choose CleanShare, and it re-presents the system share sheet with a cleaned copy ready for WhatsApp, Messages, Instagram, or anywhere else — your originals are never touched.

It removes everything that quietly travels with a file: EXIF tags, GPS coordinates, the Apple MakerNote, IPTC and XMP blocks, embedded thumbnails, QuickTime/movie metadata, and timed-metadata tracks in video. The location, camera model, and timestamps that apps and recipients can read are gone.

By default it preserves only what you need for the image to look right: orientation and the embedded color profile. Nothing else carries over.

It's fast. Photos clean instantly and video uses lossless passthrough — no re-encoding — so a 4K HEVC clip cleans in under a second with no quality loss.

CleanShare makes a simple privacy promise: no accounts, no analytics, no network. Nothing leaves your device, ever. This isn't just a claim — it's verified by CI on every commit, which fails the build if the app makes a single network request or leaves any metadata behind.

CleanShare is free and open source under the MIT license. Read every line, audit the privacy guarantees yourself, or contribute: https://github.com/donald-jackson/cleanshare

## Tags / Categories

- **Primary category:** Photo & Video
- **Secondary category:** Utilities
- Keywords: metadata, EXIF, GPS, privacy, strip, photo, video, share, location, scrub

## Age rating

4+
