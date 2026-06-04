# Contributing to CleanShare

Thanks for your interest in improving CleanShare. This document explains how to
get set up, how to propose changes, and the rules every contribution must follow.

## Development setup

Clone the repo and run the contributor bootstrap script:

```bash
./scripts/bootstrap.sh
```

It installs the toolchain, generates the Xcode project from `project.yml`, and
gets you to a buildable state. After editing `project.yml`, regenerate the
project with `./scripts/generate-project.sh`.

To build the engine package directly:

```bash
cd Packages/CleanShareCore && swift build && swift test
```

## Pull request flow

1. Fork the repo and create a topic branch off `main`.
2. Make your change in a focused, single-purpose commit (or a small series).
3. Run the full test suite and the privacy checks locally before opening the PR.
4. Open a pull request against `main`. Fill out the PR template and describe the
   change and its motivation.
5. A maintainer reviews. CI must be green before merge.

## Rules every change must follow

### Tests are required for every change

Every behavioural change must ship with tests. New engine functionality needs
unit tests in the matching `*Tests` target; UI changes need a verification step.
PRs without tests for testable changes will not be merged.

### No new third-party dependencies without an ADR

CleanShare has **zero third-party runtime dependencies** by design — the
Foundation / ImageIO / CoreGraphics / AVFoundation / SwiftUI / UIKit stack is the
entire universe. Adding any runtime dependency requires a new Architecture
Decision Record justifying it; see
[`docs/adr/0002-no-third-party-deps.md`](docs/adr/0002-no-third-party-deps.md).
PRs that add a dependency without an accompanying ADR will be declined.

### The privacy regression suite must pass

CleanShare's whole purpose is stripping identifying metadata. The privacy checks
(`make verify-strip` and `scripts/check-no-trackers.sh`) mechanically enforce
that cleaned output carries no metadata residue and that no tracker or analytics
symbols enter the source tree. **Any change that breaks the privacy regression
suite cannot be merged** — there are no exceptions and no suppressions.

## Code standards

- Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`). No
  suppressed warnings.
- Keep the engine (`CleanShareCore`) free of UIKit/SwiftUI, and keep
  `CGImage`/`AVAsset` plumbing out of views.
- No emojis in product UI, code, or docs.

## Reporting bugs and asking questions

See [`SUPPORT.md`](SUPPORT.md). For security issues, follow
[`SECURITY.md`](SECURITY.md) — do not open a public issue.
