# Threat Model

CleanShare exists to defeat one specific privacy failure: **identifying metadata
travelling with a photo or video when you share it.** This document states what
that threat is, what CleanShare does and does not defend against, and how the
defenses are mechanically enforced. It re-renders the privacy posture in
[PLAN.md](../PLAN.md) §9 and the per-format metadata risks enumerated in §4.

## Asset to protect

The user's intent. When someone shares a photo to a messaging or social app,
they intend to share the *image* — not their home GPS coordinates, the exact
capture timestamp, their camera's serial number, or an opaque token that
correlates the file back to other assets in their library. That accidental
payload is the asset we protect.

## In-scope threats

These are the threats CleanShare is designed to neutralize. All of them are
**metadata leakage at share time** — the file reaches the recipient carrying
data the user did not intend to disclose.

| Threat | Where it lives | Why it matters |
|---|---|---|
| GPS location | EXIF `{GPS}` IFD | Reveals home/work/travel; the highest-severity leak. Stripped by default; re-enabling requires an explicit Settings opt-in with a confirmation. |
| Capture timestamp | EXIF `DateTimeOriginal` | Establishes when/where someone was. Stripped by default. |
| Camera make / model / serial | EXIF `{TIFF}`, `{Exif}`, `{ExifAux}` | Fingerprints the device; serials are uniquely identifying. |
| MakerNote (esp. `{MakerApple}`) | Vendor MakerNote dictionaries | `MakerApple` key `17` carries the Live Photo pairing UUID — a correlatable token linking assets. The single biggest privacy threat per PLAN.md §4.4. |
| XMP / IPTC / Photoshop blocks | `{XMP}`, `{IPTC}`, `{Photoshop}`, `{IPTCXMP}` | Editing software embeds author, copyright, descriptions, history. |
| PNG ancillary text chunks | `tEXt`, `iTXt`, `zTXt`, `eXIf`, `tIME` | Free-form text and embedded EXIF survive naive re-encoding. |
| WebP / GIF metadata chunks | EXIF/XMP chunks, GIF application-extension blocks | Same leakage classes in container formats people forget about. |
| QuickTime / MP4 metadata atoms | `mdta` / `udta` atoms, timed-metadata tracks | Video carries GPS, model, and timed-metadata tracks (e.g. location-over-time). |
| Live Photo pairing UUID | `{MakerApple}` key 17 (still) + `com.apple.quicktime.content.identifier` (video) | An opaque token that correlates the still and its motion clip, and the asset back to the user's library. Handled per the Live Photo modes in PLAN.md §4.5. |

What we deliberately **keep** (structural / correctness, not identifying):
ICC color profile and Orientation are preserved by default so cleaned files
render correctly; pixel dimensions, duration, and codec format descriptions are
structural. See the strip/keep matrix in PLAN.md §4.4.

## Out-of-scope (non-threats / explicit non-goals)

CleanShare guarantees the file it hands to the share sheet is clean. It does
**not** control what happens after that.

- **The recipient app.** Once the cleaned file leaves CleanShare via the system
  share sheet, the destination app owns it. Many destinations (e.g. WhatsApp,
  Instagram) **re-encode** the image server-side, which strips most metadata
  anyway — but that is *their* behavior, not a guarantee CleanShare can make.
  Conversely, an app that preserves the file verbatim will faithfully forward
  CleanShare's already-clean output. Either way, CleanShare's contract ends at
  the share sheet. We do not, and cannot, audit the recipient app.
- **Pixel-level / steganographic content.** CleanShare strips *metadata*. It
  does not analyze image pixels for visible PII (faces, license plates,
  documents on a desk) or covert payloads. Cropping/redaction is the user's job.
- **The user's own device.** CleanShare assumes a non-compromised iOS device.
  It is not a defense against malware, a jailbroken OS, or someone with physical
  access to an unlocked phone.
- **Network adversaries.** There is no network surface to attack — the app and
  extension make zero network calls (enforced; see below). Transport security of
  whatever the *recipient* app does is out of scope.
- **The cleaned file at rest after handoff.** CleanShare works in an App Group
  workspace and cleans up its own temporary files. What the destination app
  persists is outside our boundary.

## Mitigations

The privacy claims above are not aspirational — they are mechanically enforced.

- **fail-closed in-process audit.** After every clean, `MetadataAuditor` re-reads
  the output and intersects its keys against a sensitive-key set, subtracting the
  user's allowlist. If *any* disallowed key remains, the engine throws
  `CleanerError.leakDetected(keys:)` and the output is **discarded** — the user
  sees an error rather than a leaky file. There is no "ship it anyway" path.
  PLAN.md §8.1.
- **Safe ImageIO write pattern.** The engine uses
  `CGImageDestinationAddImage(dest, cgImage, props)` with explicit `kCFNull`
  sentinels, never `CGImageDestinationAddImageFromSource` (which silently copies
  source metadata). A SwiftLint custom rule fails the build if the dangerous
  symbol appears. PLAN.md §4.2.
- **Golden-fixture regression tests.** Curated dirty inputs (iPhone HEIC with
  GPS + MakerApple, Android JPEG with IPTC/XMP, Lightroom export, Live Photo
  pair, animated GIF, transparent PNG, ProRes/H.264 video) are run through the
  pipeline and asserted clean via `XCTAssertNoMetadataLeak(at:allowing:)`.
  PLAN.md §8.2.
- **External-tool cross-check in CI.** Because the in-house auditor shares
  ImageIO with the writer, a hypothetical ImageIO bug could hide a tag from both.
  CI independently runs `exiftool -a -G1 -j` over cleaned outputs and asserts
  empty EXIF/XMP/GPS/IPTC/MakerNote groups, so the privacy regression is caught
  by code that does not share the failure mode. PLAN.md §8.3.
- **Zero network, verified.** `NetworkSilenceTests` (XCUITest) asserts the app
  and extension make no network requests. No analytics, no telemetry
  auto-transmission, no identifiers persisted. MetricKit is opt-in and on-device
  only. PLAN.md §9.
- **No third-party runtime dependencies.** The entire runtime is Apple's own
  frameworks, eliminating supply-chain and tracking-SDK surface.
  `scripts/check-no-trackers.sh` enforces it. PLAN.md §9; ADR 0002.

## Residual risk

The deepest residual risk is a defect in Apple's ImageIO/AVFoundation that hides
a tag from *both* the writer and our same-framework auditor. The exiftool
cross-check in CI (§8.3) exists specifically to break that shared-failure
assumption. Beyond that, anything past the share sheet — the recipient app, the
device's own integrity, the user's pixel-level content — is out of scope by
design, as stated above.
