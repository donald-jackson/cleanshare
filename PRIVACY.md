# Privacy Policy

CleanShare exists to remove identifying metadata from your photos and videos.
It would defeat the purpose to collect anything about you in return. So we don't.

## Data Not Collected

CleanShare collects **no data**. Every category in Apple's App Store Privacy
Nutrition Label is answered "No — Data Not Collected":

- No contact info, name, or email.
- No location data — including the GPS coordinates we strip from your media,
  which are discarded, never read for our own use, and never transmitted.
- No identifiers (`identifierForVendor`, advertising IDs, installation IDs, or
  any persisted device/user identifier).
- No usage data, analytics, or behavioral tracking.
- No diagnostics sent automatically (see MetricKit below).
- No purchases, financial info, contacts, browsing history, or search history.

## On-Device Only

All metadata stripping happens locally on your device. Your photos and videos
are processed in place and handed straight to the system share sheet for the
destination you choose. They are never uploaded to us or to any third party.

## No Network Calls

CleanShare makes **no network requests**. The app and its share extension
contain no networking code, no backend, no cloud sync, and no third-party SDKs.
There is no server for your data to travel to.

## Diagnostics: MetricKit, Opt-In, On-Device

Crash and performance diagnostics use Apple's **MetricKit** framework only, and
only if you explicitly opt in. The default is off. Reports stay on your device;
nothing is transmitted automatically. If you choose to share a report, you do so
manually via AirDrop or Mail to help us debug — entirely under your control.

## No Persisted Identifiers

CleanShare does not persist `identifierForVendor`, an installation date, or any
other identifier that could be used to recognize you or your device across
sessions.

## Verified by Continuous Integration

These are not just promises. CleanShare is fully open source, and we test for
privacy regressions on **every commit**:

- A network-silence test asserts the app and extension make zero network
  requests.
- A symbol scan rejects any third-party tracking or analytics SDK.
- Metadata-stripping tests assert that cleaned files carry no residual EXIF,
  GPS, MakerNote, or XMP data.

You can read every line of the source and the CI checks yourself:
`https://github.com/<placeholder>/cleanshare`.

## Changes

If this policy ever changes, the change will be visible in the repository's git
history and reflected in `CHANGELOG.md`.
