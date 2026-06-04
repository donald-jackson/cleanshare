# App Store Privacy — "Data Not Collected"

CleanShare's App Store privacy label is **Data Not Collected**. Every category in the
App Store Connect privacy questionnaire is answered **"No."** This document records why
that answer is correct and accurate, so the maintainer can fill out the questionnaire
with confidence at submission time.

References: PLAN.md §9 (Privacy Posture), §13.2 (Privacy Nutrition Label), §18 (Telemetry).

---

## Why every category is "No"

CleanShare is on-device only. There is no backend, no analytics, no auth, no cloud sync,
and no third-party runtime SDK of any kind. The app:

- Makes **no network calls** at runtime. The only `URLSession` usage anywhere in the
  codebase is in `NetworkSilenceTests`, which asserts that zero requests are made
  (verified with Network Link Conditioner at 100 % packet loss — PLAN.md §18.3).
- Persists **no identifiers**. No `identifierForVendor` reads, no installation-date or
  first-launch-ID style `UserDefaults` keys (PLAN.md §18.1).
- Uses **MetricKit only**, opt-in and on-device. Crash/performance reports are held in a
  rolling buffer of the last 5 and exported by the user manually via AirDrop/Mail. There
  is **no auto-transmission**, and diagnostics default to off (PLAN.md §18.2).
- Reads the Photo Library **only** for photos the user explicitly picks to clean; those
  photos never leave the device (`NSPhotoLibraryUsageDescription`, PLAN.md §9).

Because nothing is collected, transmitted, or linked to the user, **no data type in the
questionnaire applies.** The resulting label is **Data Not Collected**.

This is not a self-attestation we hope holds — it is mechanically enforced by CI on every
commit: `scripts/check-no-trackers.sh` fails the build if a forbidden SDK symbol appears,
and the network-silence test fails if any request is attempted (PLAN.md §18.3).

---

## How the questionnaire is submitted

The questionnaire is **not** part of this repository's metadata deliver set — it is
submitted through the **App Store Connect UI** (App Store Connect → App Privacy), with
**every data category left unchecked**. This is a one-time maintainer action tracked in
[`manual-steps.md`](./manual-steps.md) under "App Store submission."

When in doubt: do not check any data type. CleanShare collects nothing.
