# App Store Screenshots

Every screenshot here is captured from the **real product UI** exercised through real
flows (no marketing-only views, no `#if DEBUG` affordances — see CLAUDE.md "No-mocks
principle"). Status bar is pinned to 9:41 / full battery / full signal via
`xcrun simctl status_bar override`.

Re-capture at any time with `scripts/screenshots.sh` (or the manual simctl flow in
`docs/manual-steps.md`). Upload order below is the App Store Connect display order.

## Required device sizes (App Store Connect)

| Folder | Device class | Resolution (portrait) | Reference device |
|---|---|---|---|
| `iPhone-6.9/` | iPhone 6.9" | **1320 × 2868** | iPhone 17 Pro Max |
| `iPad-13/`    | iPad 13"    | **2064 × 2752** | iPad Pro 13" (M4) |

These two sizes are the only ones App Store Connect requires for a universal iOS 17+
app; smaller iPhone/iPad classes are down-scaled by Apple automatically.

## iPhone 6.9" — upload order & captions

| # | File | Source flow | Suggested caption |
|---|---|---|---|
| 1 | `01-hero.png`         | Onboarding page 1 | **Share without leaking a thing** |
| 2 | `02-diff.png`         | App → "Try it on a sample photo" → before/after diff | **See exactly what's removed — GPS, camera model, timestamps** |
| 3 | `03-how-it-works.png` | Onboarding page 2 | **Share, clean, send — three taps** |
| 4 | `04-private.png`      | Onboarding page 3 | **No accounts. No analytics. No network.** |
| 5 | `05-home.png`         | App home screen | **Clean from the app or the share sheet** |
| 6 | `06-notify.png`       | Onboarding page 4 | **Told the moment your file is clean and ready** |

## iPad 13" — upload order & captions

| # | File | Source flow | Suggested caption |
|---|---|---|---|
| 1 | `01-hero.png`         | Onboarding page 1 | **Share without leaking a thing** |
| 2 | `02-diff.png`         | App → "Try it on a sample photo" → before/after diff | **See exactly what's removed — GPS, camera model, timestamps** |
| 3 | `03-how-it-works.png` | Onboarding page 2 | **Share, clean, send — three taps** |
| 4 | `04-private.png`      | Onboarding page 3 | **No accounts. No analytics. No network.** |

The before/after diff (shot 2) is the proof shot — it shows real `{GPS}` latitude/longitude
and `{TIFF}` Make=Apple / Model="iPhone 15 Pro" struck out after cleaning. Keep it in the
first two positions; it is the most persuasive frame.
