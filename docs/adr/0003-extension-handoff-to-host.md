# 3. Extension hands off to the host app

- Status: Accepted
- Date: 2026-06-04

## Context and Problem Statement

CleanShare inserts itself into the iOS share sheet via a Share Extension. After
the extension cleans the selected media, the user still expects to re-share the
cleaned files to their chosen destination app (WhatsApp, Messages, Instagram,
etc.). The natural way to offer that choice is `UIActivityViewController` — the
system share sheet.

The problem: **a share extension cannot present `UIActivityViewController`.**
iOS does not permit one share/action extension to invoke another share sheet
from within its own hosting context. The extension therefore needs some
sanctioned mechanism to hand the cleaned output back to a context that *can*
present the system share sheet, and to do so invisibly to the user.

## Decision

The share extension hands off to the **host app** via
`NSExtensionContext.open(_:completionHandler:)` with a custom URL scheme,
`cleanshare://`.

The flow (PLAN.md §6.1):

1. The extension finishes cleaning and writes the receipts/manifest to a
   token-named inbox in the shared App Group container
   (`group.solutions.ddj.cleanshare`).
2. The extension calls
   `extensionContext?.open(URL(string: "cleanshare://handoff?t=<token>")!)`.
3. On `success == true`, it calls `completeRequest(returningItems: nil)` to
   dismiss itself.
4. The host app receives the URL via SwiftUI's `.onOpenURL`, routes it through
   `HandoffRouter`, loads the manifest by token, and presents
   `UIActivityViewController` over the cleaned output URLs.
5. After the share sheet completes, the host schedules workspace cleanup.

`NSExtensionContext.open(_:completionHandler:)` is the only sanctioned mechanism
for an extension to launch its host app, which is why it anchors this design.

### Fallback ladder (PLAN.md §6.2)

The handoff degrades gracefully rather than failing outright:

| If | Then |
|---|---|
| URL open returns `success == true` | Host presents the share sheet. Best path. |
| URL open returns `success == false` (rare; e.g. during a host-app upgrade) | Extension presents `UIDocumentPickerViewController(forExporting:)` so the user can save the cleaned files to Files. |
| User explicitly chose "Clean only, don't re-share" in Settings | Extension presents the document picker directly, skipping the handoff. |

### Alternatives considered

- **File-export fallback only** (always present a document picker, never hand
  off to the host). Rejected as the primary path: it produces a worse user
  experience — the user wanted to *share*, not to save to Files and re-pick the
  file from the destination app. It survives only as the bottom rung of the
  fallback ladder.
- **Universal Link** (`https://cleanshare.dev/share?t=<token>`) mapped to the
  same handler. Deferred to Phase 2 hardening (PLAN.md §6.3). A Universal Link
  is more robust if another app intercepts the `cleanshare://` scheme, or if a
  future iOS revision restricts cross-process custom-scheme opens, but it
  requires a deployed `apple-app-site-association` file and a live domain, which
  are not prerequisites for the initial release.

## Consequences

- **Positive:** the re-share is invisible to the user — they tap CleanShare in
  the share sheet, the extension cleans, and the system share sheet reappears
  for their chosen destination, all in one continuous flow.
- **Positive:** files never leave the device and are passed by URL within a
  shared App Group container, keeping the on-device-only guarantee intact.
- **Positive:** the fallback ladder means a failed handoff still lets the user
  recover their cleaned files via the document picker rather than losing the
  work.
- **Negative:** the host app must be installed and launchable for the best path;
  the custom scheme is theoretically interceptable by another app, which is the
  risk the Phase 2 Universal Link addresses.
- **Negative:** there is a brief context switch from the share sheet to the host
  app, which is acceptable but not entirely seamless on slower devices.

## References

- PLAN.md §6 (Re-Share UX: extension → host handoff)
- PLAN.md §6.1 (the flow), §6.2 (fallback ladder), §6.3 (Universal Link hardening)
- App Group `group.solutions.ddj.cleanshare` (shared workspace container)
- [[0001-record-architecture-decisions]]
