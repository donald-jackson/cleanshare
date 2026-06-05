# Architecture

CleanShare is an on-device iOS app that strips identifying metadata (EXIF, GPS,
camera make/model, MakerNote, XMP, etc.) from photos and videos before
re-presenting the system share sheet. There is no backend, no network, and no
third-party runtime code. This document describes the high-level structure; it
re-renders [PLAN.md](../PLAN.md) §2 and links out to the relevant ADRs.

## Workspace + targets layout

```
CleanShare.xcodeproj            (generated from project.yml via XcodeGen)
├── Target: CleanShare          (iOS host app, SwiftUI, @main)
└── Target: ShareExtension      (Share Extension, ~120 MB process cap)

Packages/
├── CleanShareCore/             (Swift Package — engine, no UI)
├── CleanShareUI/               (Swift Package — shared SwiftUI views)
└── CleanShareTesting/          (Swift Package — fixtures + assertion DSL; deferred)
```

The Xcode project is generated and gitignored; `project.yml` is the source of
truth. Re-run `./scripts/generate-project.sh` after editing it.

Both runnable targets depend on the same engine package, so the host app and the
share extension run the *identical* cleaning code path.

## Swift Package boundaries

- **`CleanShareCore`** — the metadata-stripping engine. Pure Foundation /
  ImageIO / CoreGraphics / AVFoundation / CoreMedia / UniformTypeIdentifiers.
  Contains **no** UIKit or SwiftUI. This is what makes the engine testable in
  isolation and keeps the share extension small: only the engine sources the
  extension actually references get linked into its ~120 MB process.
- **`CleanShareUI`** — shared SwiftUI views (onboarding, settings, about,
  sheets) used by both the host app and, via `UIHostingController`, the share
  extension. Contains **no** `CGImage` / `AVAsset` plumbing — that all lives in
  the engine.
- **`CleanShareTesting`** *(deferred)* — fixtures and an assertion DSL for
  metadata-residue tests.

The engine ↔ UI split is a hard rule: no UIKit/SwiftUI in `CleanShareCore`, no
media plumbing in views. See [ADR 0001](adr/0001-engine-as-swift-package.md).

## Why zero third-party dependencies

Foundation + ImageIO + CoreGraphics + AVFoundation + CoreMedia +
UniformTypeIdentifiers + PhotosUI + SwiftUI + UIKit is the entire universe. No
analytics, no crash SDK, no HTTP, no image library. For an MIT-licensed privacy
app this is non-negotiable: the code stays auditable, there is no supply-chain
attack surface, no binary bloat, and nothing to break when a dependency abandons
iOS support. The rule is mechanically enforced by
`scripts/check-no-trackers.sh`. See
[ADR 0002](adr/0002-no-third-party-deps.md).

## App Group

`group.solutions.ddj.cleanshare` (maintainers replace with their own reverse-DNS)
backs the extension → host handoff workspace. The share extension cleans files
into `AppGroup/tmp/job-<uuid>/` and writes a `manifest.json` into
`AppGroup/inbox/<token>/`; the host app reads it back after being launched.

## URL scheme

`cleanshare://handoff?t=<token>` is the extension → host open mechanism. Share
extensions cannot present `UIActivityViewController`, so the extension cleans the
media, then calls `NSExtensionContext.open(_:completionHandler:)` with the
handoff URL. The host app handles it via `.onOpenURL`, reads the manifest, and
presents the real system share sheet over the cleaned files. See
[ADR 0003](adr/0003-extension-to-host-handoff.md).

## Data flow (share-extension path)

```
[Photos / Files]  →  Share → "Clean with CleanShare"
        ▼
[ShareExtension — ~120 MB cap]
   1. Enumerate NSItemProvider attachments
   2. loadFileRepresentation → security-scoped URL
   3. APFS clone (FileManager.linkItem) into AppGroup/tmp/job-<uuid>/in/
   4. CleaningPipeline.run() strips per item
   5. MetadataAuditor audits each output; throws on any leak
   6. Write manifest.json to AppGroup/inbox/<token>/
   7. extensionContext.open(cleanshare://handoff?t=<token>)
        ▼
[CleanShare host app — launched via URL scheme]
   • HandoffRouter reads inbox/<token>/manifest.json
   • Presents UIActivityViewController over the cleaned files
   • User picks destination app → sends; job cleaned up after TTL
```

The trip through the host app is invisible: the user sees Share → CleanShare →
target app → Send, the same tap count as sharing without CleanShare.

## Related ADRs

- [ADR 0001 — Engine as a Swift Package](adr/0001-engine-as-swift-package.md)
- [ADR 0002 — No third-party runtime dependencies](adr/0002-no-third-party-deps.md)
- [ADR 0003 — Extension → host handoff via URL scheme](adr/0003-extension-to-host-handoff.md)
- [ADR 0004 — On-device-only telemetry (MetricKit)](adr/0004-on-device-telemetry.md)

> The ADRs under `docs/adr/` are authored in a later phase; until then these
> links are placeholders pointing at their final paths.
