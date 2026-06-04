# CleanShare — Development TODO

> **RULE 1 — Testing is mandatory.** A task is NOT complete until every `Test:` command exits 0 AND every `Done:` criterion is independently verifiable. If a test fails, fix the implementation; do NOT weaken the test. If you cannot make the Test pass within scope, write `.needs-human` — do NOT mark the task complete.
>
> **RULE 2 — You have vision.** Every task that touches the UI ends with a `Visual Check:` line listing the elements you must SEE in the screenshot (not just probe via `ui_describe_all`). Take the screenshot, look at it, confirm layout / colors / text are correct, and only then mark `[x]`. If anything is wrong, fix the code and re-capture before marking complete.
>
> **RULE 3 — One task per iteration.** Stay in scope. Do not refactor unrelated code, do not bundle multiple tasks into one commit, do not work ahead. The first unchecked `- [ ]` line is the only task you may touch.
>
> **RULE 4 — Read narrowly.** `PLAN.md` is 60 KB. Every task cites the sections you need under `Refs:`; read those, not the whole file. `CLAUDE.md` is the project map.
>
> **RULE 5 — Escalate human-only blockers.** Apple Developer Program enrollment, App Store Connect secrets, signing repo creation, domain purchase, and similar credential / interactive steps are NOT for the agent. Write a single-paragraph reason to `.needs-human` and stop — do NOT mark the task complete and do NOT mark it `[!]` (the loop will pause for the human).
>
> **Task format**
> - Stable ID like `1.01`, `2.03`, etc. (`phase.sequence`). IDs never change once assigned.
> - Indented bullet lines under a task are sub-steps.
> - **Test:** — a single shell command (must exit 0) OR a numbered sequence of `mcp__ios-simulator__*` MCP calls (must produce the named artefact). Re-run after every change until it passes.
> - **Visual Check:** *(UI tasks only)* — an enumerated list of things you must SEE in the screenshot at the path the Test produced. Vision-capable inspection is part of the Done criterion.
> - **Done:** — unambiguous pass/fail. "File X exists and contains string Y" or "Screenshot at path Z shows element W centered at the top". Never subjective.
> - **Refs:** — `PLAN.md §X.Y` pointers. Read only these sections.
>
> **Marking tasks**
> - `- [ ]` TODO. Pick the first one; that's your task.
> - `- [x]` DONE. Set only after Test + Done + (Visual Check if present) all pass.
> - `- [!]` SKIPPED. Set ONLY by the harness after `MAX_RETRIES` failures. You (the agent) never write `[!]` — if you're blocked, use `.needs-human` instead.
>
> **Simulator MCP tools available (use them liberally)**
> - `mcp__ios-simulator__open_simulator` — boots Simulator.app
> - `mcp__ios-simulator__get_booted_sim_id` — returns the UDID of the active sim
> - `mcp__ios-simulator__install_app` — installs a built `.app`
> - `mcp__ios-simulator__launch_app` — launches an installed bundle id
> - `mcp__ios-simulator__screenshot` — captures PNG to a path you specify
> - `mcp__ios-simulator__record_video` / `stop_recording` — captures MOV for full-flow demonstrations
> - `mcp__ios-simulator__ui_describe_all` — text dump of the visible UI hierarchy (use AS WELL AS, not INSTEAD OF, a screenshot)
> - `mcp__ios-simulator__ui_find_element` / `ui_tap` / `ui_swipe` / `ui_type` — drive interactions
> - `mcp__ios-simulator__ui_describe_point` — what's at a specific (x, y) pixel
> - `mcp__ios-simulator__ui_view` — visible-portion image (lighter than `screenshot` for quick re-checks)
>
> **Built `.app` location** — `~/Library/Developer/Xcode/DerivedData/CleanShare-*/Build/Products/Debug-iphonesimulator/CleanShare.app`. Use `find ~/Library/Developer/Xcode/DerivedData -name 'CleanShare.app' -path '*/Debug-iphonesimulator/*' -type d | head -1` to resolve the actual path.
>
> **Screenshot path scheme** — `screenshots/dev/<task-id>-<short-desc>.png` (e.g. `screenshots/dev/1.26-app-launch.png`). The `screenshots/dev/` dir is gitignored.

---

## Phase 0: Preflight (toolchain)

- [x] **0.01** Verify CLI toolchain present
  - Confirm on PATH: `xcodegen`, `xcodebuild`, `swift`, `git`, `python3`, `jq`, `exiftool`, `ffprobe`, `xcrun`.
  - If any are missing, install via Homebrew: `brew install xcodegen xcbeautify swiftlint swiftformat jq exiftool ffmpeg gh`.
  - Do NOT install anything else.
  - Test: `for c in xcodegen xcodebuild swift git python3 jq exiftool ffprobe xcrun; do command -v "$c" >/dev/null || { echo "MISSING: $c"; exit 1; }; done` — exit 0.
  - Done: All nine commands resolve on PATH. Re-running the test produces no `MISSING:` output and exits 0.
  - Refs: PLAN.md §10 (Brewfile).

- [x] **0.02** Verify full Xcode is selected (not Command Line Tools)
  - Run `xcode-select -p`. If it ends in `CommandLineTools`, the developer needs to install full Xcode and run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. That is a human-only action: write a one-paragraph reason to `.needs-human` and stop.
  - Test: `xcode-select -p | grep -qv CommandLineTools` — exit 0.
  - Done: Active developer dir does NOT end in `CommandLineTools`.
  - Refs: PLAN.md §11.1.

- [x] **0.03** Verify at least one iPhone simulator runtime is available
  - `xcrun simctl list devices available` must list at least one iPhone device. If none, prompt the human via `.needs-human` to install an iOS Simulator runtime through Xcode → Settings → Components.
  - Test: `xcrun simctl list devices available | grep -q '^[[:space:]]*iPhone'` — exit 0.
  - Done: At least one available iPhone simulator is listed.
  - Refs: PLAN.md §11.1.

---

## Phase 1: Foundation — repo skeleton

- [x] **1.01** Initialise git repo
  - `git init -b main` if not already a repo. Do NOT change global `user.email` / `user.name`.
  - If signing is globally enabled but the user has no signing key set up, the build.sh harness will already work without signing; do not disable signing config — just commit normally and rely on the user's existing setup.
  - Test: `git rev-parse --is-inside-work-tree` prints `true`.
  - Done: `.git/` exists and `git status` runs without error.
  - Refs: PLAN.md §10.

- [x] **1.02** Write LICENSE (MIT, 2026)
  - Standard MIT text, copyright holder `CleanShare contributors`, year `2026`. Use the canonical MIT phrasing (https://opensource.org/licenses/MIT) — no modifications.
  - Test: `grep -q 'MIT License' LICENSE && grep -q '2026 CleanShare contributors' LICENSE && grep -q 'Permission is hereby granted' LICENSE`.
  - Done: All three greps succeed.
  - Refs: PLAN.md §15.

- [x] **1.03** Write .gitignore
  - Cover: `.DS_Store`, `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `.build/`, `CleanShare.xcodeproj/`, `Config/Local.xcconfig`, `fastlane/report.xml`, `fastlane/Preview.html`, `fastlane/screenshots`, `fastlane/test_output`, `vendor/`, `tmp/`, `.build-logs/`, `.build-state`, `.needs-human`, `coverage/`, `*.ipa`, `*.dSYM.zip`, `screenshots/dev/`, `*.swp`, `.swiftpm/`, `node_modules/`.
  - Test: `for p in DerivedData '.build/' 'CleanShare.xcodeproj/' Local.xcconfig '.build-state' '.needs-human' 'screenshots/dev/'; do grep -qF "$p" .gitignore || { echo "missing pattern: $p"; exit 1; }; done`.
  - Done: All required patterns present.
  - Refs: PLAN.md §10.

- [x] **1.04** Write .gitattributes
  - Enforce LF line endings: `*.swift text eol=lf`, `*.md text eol=lf`, `*.yml text eol=lf`, `*.sh text eol=lf`, `*.json text eol=lf`. Also `*.png binary` and `*.jpg binary`.
  - Test: `test -f .gitattributes && grep -q 'eol=lf' .gitattributes && grep -q 'png binary' .gitattributes`.
  - Done: File exists and contains both LF + binary directives.
  - Refs: PLAN.md §10.

- [x] **1.05** Write .editorconfig
  - `root = true`. Default `[*]` block: `end_of_line = lf`, `insert_final_newline = true`, `charset = utf-8`, `trim_trailing_whitespace = true`. `[*.swift]` block: `indent_style = space`, `indent_size = 4`. `[*.{yml,yaml,json}]`: `indent_size = 2`. `[*.md]`: `trim_trailing_whitespace = false` (markdown trailing spaces sometimes have meaning).
  - Test: `test -f .editorconfig && grep -q 'root = true' .editorconfig && grep -q 'indent_size = 4' .editorconfig && grep -q '\[*.md\]' .editorconfig`.
  - Done: All three directives present.
  - Refs: PLAN.md §10.

- [x] **1.06** Write .swift-version
  - Single line: `6.0`. No trailing whitespace.
  - Test: `[ "$(cat .swift-version)" = "6.0" ]`.
  - Done: File contents exactly `6.0\n`.
  - Refs: PLAN.md §10, §7.

- [x] **1.07** Write .swiftformat config
  - Set: `--swiftversion 6.0`, `--indent 4`, `--maxwidth 120`, `--commas inline`, `--header strip`, `--ifdef no-indent`, `--self insert`, `--patternlet inline`.
  - Test: `test -f .swiftformat && grep -q '\-\-swiftversion 6.0' .swiftformat && grep -q '\-\-maxwidth 120' .swiftformat`.
  - Done: Both directives present.
  - Refs: PLAN.md §10.

- [x] **1.08** Write .swiftlint.yml with banned-symbol custom rule
  - Opted-in rules include `closure_spacing`, `explicit_init`, `force_unwrapping`, `implicit_return`, `redundant_nil_coalescing`, `trailing_closure`, plus a `custom_rules` block:
    ```yaml
    custom_rules:
      forbidden_addImageFromSource:
        name: "ImageIO leak risk"
        regex: "CGImageDestinationAddImageFromSource"
        message: "Use CGImageDestinationAddImage with explicit kCFNull properties — see PLAN.md §4.2"
        severity: error
    ```
  - Set `disabled_rules: []` (we want the strict default set) and `excluded: [Packages/*/.build, DerivedData]`.
  - Test: `test -f .swiftlint.yml && grep -q 'CGImageDestinationAddImageFromSource' .swiftlint.yml && grep -q 'severity: error' .swiftlint.yml && grep -q 'kCFNull' .swiftlint.yml`.
  - Done: All four greps succeed AND `swiftlint --config .swiftlint.yml lint --quiet 2>&1 || true` does not print a "configuration error".
  - Refs: PLAN.md §4.2, §11.1.

- [x] **1.09** Write Brewfile
  - Required entries (one per line): `brew "xcodegen"`, `brew "swiftlint"`, `brew "swiftformat"`, `brew "xcbeautify"`, `brew "fastlane"`, `brew "gh"`, `brew "jq"`, `brew "exiftool"`, `brew "ffmpeg"`.
  - Test: `for t in xcodegen swiftlint swiftformat xcbeautify fastlane gh jq exiftool ffmpeg; do grep -q "brew \"$t\"" Brewfile || { echo "missing: $t"; exit 1; }; done`.
  - Done: All nine tools present.
  - Refs: PLAN.md §10.

- [x] **1.10** Write Makefile
  - Phony targets: `bootstrap`, `gen`, `build`, `test`, `lint`, `format`, `verify-strip`, `clean`, `screenshots`.
  - `gen` runs `./scripts/generate-project.sh`. `build` runs xcodebuild iOS Simulator with `CODE_SIGNING_ALLOWED=NO`. `test` runs both `swift test --package-path Packages/CleanShareCore` AND `xcodebuild test` for the app scheme. `lint` runs `swiftformat --lint . && swiftlint --strict`. `format` runs `swiftformat .`. `verify-strip` cleans every fixture via the CLI shim (set up in task 2.13) and runs `scripts/verify-metadata-stripped.sh tests/fixtures/cleaned/*`. `clean` removes `DerivedData`, `.build`, `CleanShare.xcodeproj`. `screenshots` runs `./scripts/screenshots.sh`.
  - Test: `make -n bootstrap >/dev/null && make -n gen >/dev/null && make -n build >/dev/null && make -n test >/dev/null && make -n lint >/dev/null && make -n verify-strip >/dev/null && make -n clean >/dev/null`.
  - Done: All seven targets resolve via `make -n` without errors.
  - Refs: PLAN.md §10.

- [x] **1.11** Write Config/Shared.xcconfig + Local.xcconfig.example
  - `Config/Shared.xcconfig`:
    ```
    SWIFT_VERSION = 6.0
    IPHONEOS_DEPLOYMENT_TARGET = 17.0
    TARGETED_DEVICE_FAMILY = 1,2
    SWIFT_STRICT_CONCURRENCY = complete
    ENABLE_USER_SCRIPT_SANDBOXING = YES
    GCC_TREAT_WARNINGS_AS_ERRORS = YES
    SWIFT_TREAT_WARNINGS_AS_ERRORS = YES
    ```
  - `Config/Local.xcconfig.example`:
    ```
    // Copy this file to Local.xcconfig and edit. Local.xcconfig is gitignored.
    DEVELOPMENT_TEAM_OVERRIDE = ABCDE12345
    BUNDLE_PREFIX = dev.cleanshare
    ```
  - Test: `test -f Config/Shared.xcconfig && grep -q 'SWIFT_STRICT_CONCURRENCY = complete' Config/Shared.xcconfig && grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 17.0' Config/Shared.xcconfig && test -f Config/Local.xcconfig.example && grep -q 'BUNDLE_PREFIX' Config/Local.xcconfig.example`.
  - Done: Both files exist with the required directives.
  - Refs: PLAN.md §12.2.

- [x] **1.12** Write Config/Debug.xcconfig + Config/Release.xcconfig
  - `Config/Debug.xcconfig`:
    ```
    #include "Shared.xcconfig"
    #include? "Local.xcconfig"
    CODE_SIGN_STYLE = Automatic
    DEVELOPMENT_TEAM = $(DEVELOPMENT_TEAM_OVERRIDE)
    PRODUCT_BUNDLE_IDENTIFIER = $(BUNDLE_PREFIX).app
    SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
    ```
  - `Config/Release.xcconfig`:
    ```
    #include "Shared.xcconfig"
    CODE_SIGN_STYLE = Manual
    SWIFT_OPTIMIZATION_LEVEL = -O
    ```
  - Test: `test -f Config/Debug.xcconfig && grep -q '\#include? "Local.xcconfig"' Config/Debug.xcconfig && test -f Config/Release.xcconfig && grep -q 'CODE_SIGN_STYLE = Manual' Config/Release.xcconfig`.
  - Done: Both files exist with the right includes + signing styles.
  - Refs: PLAN.md §12.2.

- [x] **1.13** Write project.yml (XcodeGen spec — full, all three targets + tests)
  - Top of file:
    ```yaml
    name: CleanShare
    options:
      bundleIdPrefix: dev.cleanshare
      deploymentTarget:
        iOS: "17.0"
      createIntermediateGroups: true
      generateEmptyDirectories: false
    settings:
      base:
        SWIFT_VERSION: "6.0"
        SWIFT_STRICT_CONCURRENCY: complete
    configs:
      Debug: debug
      Release: release
    configFiles:
      Debug: Config/Debug.xcconfig
      Release: Config/Release.xcconfig
    packages:
      CleanShareCore:
        path: Packages/CleanShareCore
    ```
  - Targets:
    - `CleanShare` — `type: application`, `supportedDestinations: [iOS]`, `sources: [App]`, `dependencies: [{ package: CleanShareCore }, { target: CleanShareShareExt, embed: true }]`. Reference `App/CleanShare.entitlements` and `App/Resources/Info.plist` via `entitlements.path` and `info.path` (do NOT use `properties:` — we hand-author the Info.plist for full control of `CFBundleURLTypes`).
    - `CleanShareShareExt` — `type: app-extension`, `supportedDestinations: [iOS]`, `sources: [ShareExtension]`, `dependencies: [{ package: CleanShareCore }]`, with entitlements + Info.plist paths to the hand-authored files in `ShareExtension/`.
    - Three test bundles — `CleanShareTests` (type: bundle.unit-test, sources: [CleanShareTests], dependencies on `CleanShare`), `CleanShareUITests` (type: bundle.ui-testing, sources: [CleanShareUITests], dependencies on `CleanShare`), `ShareExtensionTests` (type: bundle.unit-test, sources: [ShareExtensionTests], dependencies on `CleanShareShareExt`).
  - Use `mcp__context7__query-docs` on `/yonaskolb/xcodegen` if you hit any "unrecognized key" error.
  - Test: `test -f project.yml && python3 -c "import yaml; d=yaml.safe_load(open('project.yml')); assert 'CleanShare' in d['targets'], 'app target missing'; assert 'CleanShareShareExt' in d['targets'], 'extension missing'; assert 'CleanShareTests' in d['targets'], 'unit tests missing'; assert 'CleanShareUITests' in d['targets'], 'ui tests missing'; assert d['packages']['CleanShareCore']['path']=='Packages/CleanShareCore', 'package path wrong'"`.
  - Done: All five targets parse cleanly out of the YAML.
  - Refs: PLAN.md §2, §10.

- [x] **1.14** Write scripts/generate-project.sh
  - Contents:
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    cd "$(dirname "$0")/.."
    xcodegen generate
    ```
  - `chmod +x`. Idempotent — running twice produces the same `CleanShare.xcodeproj`.
  - Test: `test -x scripts/generate-project.sh && bash -n scripts/generate-project.sh`.
  - Done: Script is executable and parses without syntax errors.
  - Refs: PLAN.md §10.

- [x] **1.15** Scaffold App/CleanShareApp.swift + RootView + HandoffRouter stub
  - `App/CleanShareApp.swift`:
    ```swift
    import SwiftUI

    @main
    struct CleanShareApp: App {
        var body: some Scene {
            WindowGroup {
                RootView()
                    .onOpenURL { url in
                        _ = HandoffRouter.handle(url)
                    }
            }
        }
    }
    ```
  - `App/Views/RootView.swift`:
    ```swift
    import SwiftUI

    struct RootView: View {
        var body: some View {
            VStack(spacing: 16) {
                Text("CleanShare")
                    .font(.largeTitle).bold()
                Text("Strip metadata before sharing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    ```
  - `App/Handoff/HandoffRouter.swift`:
    ```swift
    import Foundation

    enum HandoffRouter {
        @discardableResult
        static func handle(_ url: URL) -> Bool {
            // Real implementation comes in task 3.13. For now, accept any
            // cleanshare:// URL silently so the app does not crash.
            return url.scheme == "cleanshare"
        }
    }
    ```
  - Test: `test -f App/CleanShareApp.swift && grep -q '@main' App/CleanShareApp.swift && test -f App/Views/RootView.swift && grep -q 'CleanShare' App/Views/RootView.swift && test -f App/Handoff/HandoffRouter.swift && grep -q 'cleanshare' App/Handoff/HandoffRouter.swift`.
  - Done: All three Swift files exist with the expected symbols.
  - Refs: PLAN.md §10, §6.

- [x] **1.16** Write App/Resources/Info.plist
  - Required keys:
    - `CFBundleDisplayName` = `CleanShare`
    - `CFBundleShortVersionString` = `$(MARKETING_VERSION)` (will be `0.1.0` via xcconfig later)
    - `CFBundleVersion` = `$(CURRENT_PROJECT_VERSION)`
    - `CFBundleURLTypes` = array with one entry: `CFBundleURLName` = `dev.cleanshare.app`, `CFBundleURLSchemes` = `[cleanshare]`
    - `NSPhotoLibraryUsageDescription` = `CleanShare uses Photo Library access only to pick photos you choose to clean. Photos never leave your device.`
    - `ITSAppUsesNonExemptEncryption` = `false`
    - `UIApplicationSceneManifest` = empty dict with `UIApplicationSupportsMultipleScenes = false`
    - `UISupportedInterfaceOrientations` = `[UIInterfaceOrientationPortrait, UIInterfaceOrientationLandscapeLeft, UIInterfaceOrientationLandscapeRight]`
  - Test: `plutil -lint App/Resources/Info.plist && plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.0 raw App/Resources/Info.plist | grep -q '^cleanshare$' && plutil -extract NSPhotoLibraryUsageDescription raw App/Resources/Info.plist | grep -q 'never leave'`.
  - Done: All assertions pass.
  - Refs: PLAN.md §6, §9.

- [x] **1.17** Write App/CleanShare.entitlements + AppIcon stub
  - `App/CleanShare.entitlements` is a plist with `com.apple.security.application-groups` = `[group.dev.cleanshare.app]`.
  - `App/Resources/Assets.xcassets/Contents.json` = `{"info": {"version": 1, "author": "xcode"}}`.
  - `App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` = minimal stub: `{"images": [{"idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"version": 1, "author": "xcode"}}`. (The real icon image lands in task 4.13.)
  - Test: `plutil -lint App/CleanShare.entitlements && plutil -extract 'com.apple.security.application-groups.0' raw App/CleanShare.entitlements | grep -q '^group.dev.cleanshare.app$' && test -f App/Resources/Assets.xcassets/Contents.json && test -f App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json && python3 -c "import json; json.load(open('App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json'))"`.
  - Done: All four assertions pass.
  - Refs: PLAN.md §2, §6.

- [x] **1.18** Scaffold ShareExtension/ShareViewController.swift (stub)
  - Real wiring comes in 3.11; for now create a minimal subclass:
    ```swift
    import UIKit

    final class ShareViewController: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            // Real flow lands in task 3.11
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    ```
  - Test: `test -f ShareExtension/ShareViewController.swift && grep -q 'final class ShareViewController' ShareExtension/ShareViewController.swift && grep -q 'extensionContext' ShareExtension/ShareViewController.swift`.
  - Done: Stub file exists with the expected class and immediately-completes call (so a stray Share-sheet tap in dev doesn't hang).
  - Refs: PLAN.md §3.1.

- [x] **1.19** Write ShareExtension/Info.plist (NSExtension dict)
  - `NSExtension` dict with:
    - `NSExtensionPointIdentifier` = `com.apple.share-services`
    - `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).ShareViewController`
    - `NSExtensionAttributes.NSExtensionActivationRule` = `SUBQUERY (extensionItems, $item, SUBQUERY ($item.attachments, $att, ANY $att.registeredTypeIdentifiers UTI-CONFORMS-TO \"public.image\" || ANY $att.registeredTypeIdentifiers UTI-CONFORMS-TO \"public.movie\").@count > 0).@count > 0` with reasonable counts (e.g. `NSExtensionActivationSupportsImageWithMaxCount` = 50, `NSExtensionActivationSupportsMovieWithMaxCount` = 10).
  - Also `CFBundleDisplayName` = `Clean with CleanShare`.
  - Test: `plutil -lint ShareExtension/Info.plist && plutil -extract NSExtension.NSExtensionPointIdentifier raw ShareExtension/Info.plist | grep -q '^com.apple.share-services$' && plutil -extract NSExtension.NSExtensionPrincipalClass raw ShareExtension/Info.plist | grep -q 'ShareViewController$'`.
  - Done: All three assertions pass.
  - Refs: PLAN.md §3.1.

- [x] **1.20** Write ShareExtension/ShareExtension.entitlements
  - Same App Group as host: `com.apple.security.application-groups` = `[group.dev.cleanshare.app]`.
  - Test: `plutil -lint ShareExtension/ShareExtension.entitlements && plutil -extract 'com.apple.security.application-groups.0' raw ShareExtension/ShareExtension.entitlements | grep -q '^group.dev.cleanshare.app$'`.
  - Done: Plist is valid AND the App Group identifier matches the host app.
  - Refs: PLAN.md §2.

- [x] **1.21** Write Packages/CleanShareCore/Package.swift
  - `swift-tools-version: 6.0`. Platforms `.iOS(.v17)`. Products: one library `CleanShareCore`. Targets: `CleanShareCore` at `Sources/CleanShareCore`, plus `CleanShareCoreTests` at `Tests/CleanShareCoreTests`.
  - Test: `test -f Packages/CleanShareCore/Package.swift && grep -q 'swift-tools-version: 6.0' Packages/CleanShareCore/Package.swift && grep -q '\.iOS(\.v17)' Packages/CleanShareCore/Package.swift && cd Packages/CleanShareCore && swift package describe --type json | python3 -c 'import json,sys; d=json.load(sys.stdin); names=[t["name"] for t in d["targets"]]; assert "CleanShareCore" in names; assert "CleanShareCoreTests" in names'`.
  - Done: Package describes both targets via SwiftPM.
  - Refs: PLAN.md §2, §10.

- [x] **1.22** Add CleanShareCore placeholder source + first test
  - `Packages/CleanShareCore/Sources/CleanShareCore/CleanShareCore.swift`:
    ```swift
    public enum CleanShareCore {
        public static let version = "0.0.0"
    }
    ```
  - `Packages/CleanShareCore/Tests/CleanShareCoreTests/CleanShareCoreTests.swift`:
    ```swift
    import XCTest
    @testable import CleanShareCore

    final class CleanShareCoreTests: XCTestCase {
        func testVersionNotEmpty() {
            XCTAssertFalse(CleanShareCore.version.isEmpty)
        }
    }
    ```
  - Test: `cd Packages/CleanShareCore && swift build && swift test --filter testVersionNotEmpty`.
  - Done: Build succeeds AND the single test passes.
  - Refs: PLAN.md §10.

- [x] **1.23** Run `./scripts/generate-project.sh` and verify all 5 targets
  - Resolve any XcodeGen error (the most common: a typoed setting key, or missing source dir — create the empty `CleanShareTests/`, `CleanShareUITests/`, `ShareExtensionTests/` dirs if needed; XcodeGen needs them to exist with at least one file. Add a `Tests/Placeholder.swift` per dir containing `import XCTest; final class PlaceholderTests: XCTestCase { func testTrue() { XCTAssertTrue(true) } }`).
  - Test:
    ```bash
    ./scripts/generate-project.sh && \
    xcodebuild -project CleanShare.xcodeproj -list 2>&1 | \
      python3 -c "import sys; out=sys.stdin.read(); [sys.exit(f'missing target: {t}') for t in ['CleanShare','CleanShareShareExt','CleanShareTests','CleanShareUITests','ShareExtensionTests'] if t not in out]"
    ```
  - Done: `xcodebuild -list` shows all five targets; the script exits 0.
  - Refs: PLAN.md §10.

- [x] **1.24** Build host app for iOS Simulator (no signing)
  - Run:
    ```bash
    xcodebuild \
      -project CleanShare.xcodeproj \
      -scheme CleanShare \
      -destination 'generic/platform=iOS Simulator' \
      -configuration Debug \
      build \
      CODE_SIGN_IDENTITY="" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO \
      | xcbeautify --renderer terminal
    ```
  - Fix any compile errors in the scaffold (these will mostly be import-missing or typo errors).
  - Test: The above command exits 0.
  - Done: Output contains `** BUILD SUCCEEDED **`.
  - Refs: PLAN.md §11.1.

- [x] **1.25** Boot simulator, install built `.app`, launch app
  - `mcp__ios-simulator__open_simulator`.
  - `mcp__ios-simulator__get_booted_sim_id` — record the UDID (use the latest iPhone runtime if multiple sims are available; prefer iPhone 16 / 17 Pro).
  - Resolve built path: `find ~/Library/Developer/Xcode/DerivedData -name 'CleanShare.app' -path '*/Debug-iphonesimulator/*' -type d | head -1`.
  - `mcp__ios-simulator__install_app` with that path.
  - `mcp__ios-simulator__launch_app` with bundle id `dev.cleanshare.app` (or whatever `BUNDLE_PREFIX.app` resolves to from `Config/Local.xcconfig` — read the file if present).
  - Wait ~2 seconds for the SwiftUI scene to render (the simulator MCP tools do not block on launch).
  - Test: `mcp__ios-simulator__ui_describe_all` returns output containing the string `CleanShare` (case-sensitive).
  - Done: `ui_describe_all` output includes both `CleanShare` and `Strip metadata before sharing`.
  - Refs: PLAN.md §3, §10.

- [x] **1.26** Capture launch screenshot + visual inspection
  - `mcp__ios-simulator__screenshot` → `screenshots/dev/1.26-app-launch.png`.
  - Look at the screenshot (you have vision). Confirm:
    1. White (or system background) screen.
    2. "CleanShare" rendered large and centered horizontally near the vertical center.
    3. "Strip metadata before sharing" subhead in secondary (grey) color, just below the title.
    4. No layout glitches (overlapping text, clipped letters, dark mode bleed, debug labels).
  - If anything is off, fix `App/Views/RootView.swift` and re-capture.
  - Test: `test -f screenshots/dev/1.26-app-launch.png && [ "$(stat -f %z screenshots/dev/1.26-app-launch.png 2>/dev/null || stat -c %s screenshots/dev/1.26-app-launch.png)" -gt 10000 ]`.
  - Visual Check: title text "CleanShare" visible and not truncated; subtitle visible; no error overlays.
  - Done: PNG file >10 KB exists AND the four visual criteria above are satisfied.
  - Refs: PLAN.md §3.

- [x] **1.27** Write README.md
  - Sections (use markdown headings):
    - One-line tagline + badges block (placeholders for TestFlight, App Store, GitHub Actions, License — all `<!-- TODO -->` comments are fine for now).
    - `## What it does` — 3-sentence summary.
    - `## What gets stripped` — bullet list pulled from PLAN.md §4.4 (EXIF, GPS, MakerNote, IPTC/XMP, QuickTime metadata atoms, timed-metadata tracks).
    - `## What gets preserved` — ICC color profile (toggleable), orientation, codec format descriptions.
    - `## Install` — TestFlight badge placeholder + a "Build from source" section pointing to `scripts/bootstrap.sh`.
    - `## Privacy` — link to `PRIVACY.md`.
    - `## Threat model` — link to `docs/threat-model.md` (will be created in 7.07).
    - `## Contributing` — link to `CONTRIBUTING.md`.
  - Embed `screenshots/dev/1.26-app-launch.png` as the README hero image (with appropriate alt text). Note this is a placeholder until 4.x produces polished UI.
  - Test: `test -f README.md && for h in 'What it does' 'What gets stripped' 'What gets preserved' Install Privacy 'Threat model' Contributing; do grep -q "## $h" README.md || { echo "missing heading: $h"; exit 1; }; done && grep -q 'screenshots/dev/1.26' README.md`.
  - Done: All seven required headings present AND the launch screenshot is referenced.
  - Refs: PLAN.md §10, §14.

- [ ] **1.28** Write CHANGELOG.md
  - Keep a Changelog 1.1.0 format. Header block:
    ```markdown
    # Changelog

    All notable changes to this project will be documented in this file.

    The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
    and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

    ## [Unreleased]
    ```
  - Test: `grep -q '\[Unreleased\]' CHANGELOG.md && grep -q 'Keep a Changelog' CHANGELOG.md && grep -q 'Semantic Versioning' CHANGELOG.md`.
  - Done: All three references present.
  - Refs: PLAN.md §16.

- [ ] **1.29** Write CONTRIBUTING.md + SUPPORT.md
  - `CONTRIBUTING.md` — covers: development setup pointer to `scripts/bootstrap.sh`, PR flow, the "tests required for every change" rule, the "no new third-party deps without an ADR" rule (link to `docs/adr/0002-no-third-party-deps.md` even though that's created in task 7.09), the privacy-regression must-pass rule.
  - `SUPPORT.md` — short pointer to Issues for bugs and Discussions for questions; explicitly redirects security reports to `SECURITY.md`.
  - Test: `test -f CONTRIBUTING.md && grep -q bootstrap CONTRIBUTING.md && grep -q 'third-party' CONTRIBUTING.md && grep -q privacy CONTRIBUTING.md && test -f SUPPORT.md && grep -q SECURITY.md SUPPORT.md`.
  - Done: Both files exist with the required pointers.
  - Refs: PLAN.md §17.

- [ ] **1.30** Write CODE_OF_CONDUCT.md (Contributor Covenant 2.1)
  - Use the verbatim text of Contributor Covenant 2.1 from https://www.contributor-covenant.org/version/2/1/code_of_conduct/code_of_conduct.md.
  - Set the contact email to `conduct@cleanshare.dev` (placeholder for now; documented in `docs/manual-steps.md` as needing real mailbox setup).
  - Test: `grep -q 'Contributor Covenant' CODE_OF_CONDUCT.md && grep -q 'version/2/1' CODE_OF_CONDUCT.md && grep -q '@cleanshare.dev' CODE_OF_CONDUCT.md`.
  - Done: All three present.
  - Refs: PLAN.md §17.

- [ ] **1.31** Write SECURITY.md + PRIVACY.md
  - `SECURITY.md` — explains the supported versions table (latest only for now), how to report vulnerabilities (GitHub Security Advisories — `https://github.com/<placeholder>/cleanshare/security/advisories/new`), DO NOT file public issues for privacy/security bugs.
  - `PRIVACY.md` — mirrors PLAN.md §9: "Data Not Collected" across all categories, MetricKit opt-in only, no network calls, no identifiers persisted, full source-code link, CI verification claim ("we test for it on every commit").
  - Test: `test -f SECURITY.md && grep -q 'Security Advisor' SECURITY.md && test -f PRIVACY.md && grep -q 'Data Not Collected' PRIVACY.md && grep -q 'MetricKit' PRIVACY.md && grep -q 'no network' PRIVACY.md`.
  - Done: Both files exist with the required content.
  - Refs: PLAN.md §9, §17.

- [ ] **1.32** Write .github/CODEOWNERS + dependabot.yml + FUNDING.yml
  - `.github/CODEOWNERS` — per PLAN.md §17.4: `*` → `@<maintainer>`; `/ShareExtension/`, `/Packages/CleanShareCore/Sources/Verification/`, `/.github/workflows/` all also `@<maintainer>`.
  - `.github/dependabot.yml`:
    ```yaml
    version: 2
    updates:
      - package-ecosystem: github-actions
        directory: "/"
        schedule:
          interval: weekly
    ```
  - `.github/FUNDING.yml` — single line: `# Funding sources are configured per maintainer — see docs/manual-steps.md`.
  - Test: `test -f .github/CODEOWNERS && grep -q '^\*' .github/CODEOWNERS && test -f .github/dependabot.yml && grep -q 'github-actions' .github/dependabot.yml && python3 -c "import yaml; yaml.safe_load(open('.github/dependabot.yml'))" && test -f .github/FUNDING.yml`.
  - Done: All three files present; dependabot YAML parses.
  - Refs: PLAN.md §17.

- [ ] **1.33** Write .github/pull_request_template.md
  - Use the template from PLAN.md §17.3 verbatim (What / Why / How / Test plan checklist / Checklist).
  - Test: `test -f .github/pull_request_template.md && grep -q '## What' .github/pull_request_template.md && grep -q '## Test plan' .github/pull_request_template.md && grep -q 'verify-metadata-stripped' .github/pull_request_template.md`.
  - Done: Template present with all required sections.
  - Refs: PLAN.md §17.3.

- [ ] **1.34** Write .github/ISSUE_TEMPLATE/* files
  - `.github/ISSUE_TEMPLATE/config.yml` — `blank_issues_enabled: false`, links to Discussions + Security Advisories.
  - `.github/ISSUE_TEMPLATE/bug_report.yml` — fields: summary, steps to reproduce, expected, actual, iOS version, device.
  - `.github/ISSUE_TEMPLATE/feature_request.yml` — fields: problem, proposed solution, alternatives.
  - `.github/ISSUE_TEMPLATE/privacy_leak_report.yml` — top banner: "If this concerns a real user's data, STOP and use Security Advisories instead." Fields: format, sample file (optional, redacted), what metadata leaked, where it was visible.
  - Test: `for f in config bug_report feature_request privacy_leak_report; do test -f ".github/ISSUE_TEMPLATE/$f.yml" || exit 1; python3 -c "import yaml; yaml.safe_load(open('.github/ISSUE_TEMPLATE/$f.yml'))" || exit 1; done && grep -q 'blank_issues_enabled: false' .github/ISSUE_TEMPLATE/config.yml`.
  - Done: All four files exist and parse as valid YAML.
  - Refs: PLAN.md §17.

- [ ] **1.35** Write .github/workflows/pr.yml (lint + build minimum)
  - Triggers: `push.branches: [main]` AND `pull_request.branches: [main]`.
  - Concurrency: `group: pr-${{ github.ref }}` with `cancel-in-progress: true`.
  - Single job `validate` on `macos-15`, `timeout-minutes: 25`.
  - Steps: checkout v4 → select Xcode 16 (`sudo xcode-select -s /Applications/Xcode_16.app`) → `brew install xcodegen swiftformat swiftlint xcbeautify` → `swiftformat --lint .` → `swiftlint --strict` → `./scripts/generate-project.sh` → build iOS Simulator scheme with the same no-signing flags as task 1.24.
  - Test: `test -f .github/workflows/pr.yml && python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/pr.yml')); assert 'jobs' in d and 'validate' in d['jobs']; assert 'cancel-in-progress' in str(d)" && grep -q xcodegen .github/workflows/pr.yml && grep -q 'CODE_SIGNING_ALLOWED=NO' .github/workflows/pr.yml`.
  - Done: Workflow YAML parses; has the required steps + cancel-in-progress.
  - Refs: PLAN.md §11.1.

- [ ] **1.36** Initial commit (Phase 1)
  - `git add` ONLY the files created during Phase 1. Explicitly DO NOT add `CleanShare.xcodeproj/`, `Config/Local.xcconfig`, `.build-logs/`, `.build-state`, `.needs-human`, `screenshots/dev/`, `DerivedData/`.
  - Stage selectively: `git add LICENSE .gitignore .gitattributes .editorconfig .swift-version .swiftformat .swiftlint.yml Brewfile Makefile Config/ project.yml scripts/ App/ ShareExtension/ Packages/ README.md CHANGELOG.md CONTRIBUTING.md SUPPORT.md CODE_OF_CONDUCT.md SECURITY.md PRIVACY.md .github/`.
  - Run `git status --short` first to inspect; if any tracked-but-shouldn't-be path appears (`.build-state`, `Config/Local.xcconfig`, etc.), abort and fix `.gitignore`.
  - Commit message: `feat: phase 1 — repo skeleton, scaffolded app + extension + core, OSS surface`.
  - Do NOT push.
  - Test: `git log --oneline -1 | grep -q 'phase 1' && ! git ls-files | grep -q 'CleanShare.xcodeproj' && ! git ls-files | grep -q 'Local.xcconfig$' && ! git ls-files | grep -q '\.build-state'`.
  - Done: Commit exists AND none of the excluded paths are tracked.
  - Refs: PLAN.md §10, §20 Week 1.


## Phase 2: Image cleaner + fixtures

- [ ] **2.01** Define MediaKind enum
  - File: `Packages/CleanShareCore/Sources/CleanShareCore/Model/MediaKind.swift`.
  - `public enum MediaKind: String, Sendable, CaseIterable, Codable { case jpeg, heic, heif, png, gif, webp, tiff, dng, mp4, mov, livePhoto }`.
  - Add `public var cfType: CFString { get }` returning the right `kUTType*` / system UTI string per case (e.g. `kUTTypeJPEG` for `.jpeg`; for `.heic` / `.heif` use `"public.heic"` / `"public.heif"` as CFString).
  - Add `public init?(uti type: UTType)` mapping the iOS 14+ `UTType` to a MediaKind case.
  - Test: `cd Packages/CleanShareCore && swift build && swift -e 'import CleanShareCore; precondition(MediaKind(rawValue: "jpeg") == .jpeg)' 2>/dev/null || true; cd Packages/CleanShareCore && swift test --filter MediaKindTests 2>/dev/null || true; grep -c '^\s*case ' Sources/CleanShareCore/Model/MediaKind.swift | awk '$1 >= 11 { exit 0 } { exit 1 }'`.
  - Done: Package compiles; the enum has at least 11 cases.
  - Refs: PLAN.md §4.1.

- [ ] **2.02** Define CleaningPreferences struct
  - File: `Packages/CleanShareCore/Sources/CleanShareCore/Model/CleaningPreferences.swift`.
  - Replicate PLAN.md §4.6 exactly (all `public var` fields, all defaults). At minimum: `keepOrientation = true`, `keepICCProfile = true`, `keepCaptureDate = false`, `keepGPS = false`, `keepCameraMakeModel = false`, `keepCustomXMP = false`, `preserveVideoCreationDate = false`, `livePhotoMode: LivePhotoMode = .prompt`.
  - Add `public func allowedKeys() -> Set<String>` that returns the string set of CGImage property keys derived from the toggles (used by `MetadataAuditor`).
  - Mark `public struct CleaningPreferences: Sendable, Equatable, Codable`.
  - Test: `cd Packages/CleanShareCore && swift build && swift package describe --type json | python3 -c "import json,sys; d=json.load(sys.stdin); print('ok')"`.
  - Done: Builds; the struct lives in `Model/`.
  - Refs: PLAN.md §4.6.

- [ ] **2.03** Define LivePhotoMode enum
  - File: `Packages/CleanShareCore/Sources/CleanShareCore/Model/LivePhotoMode.swift`.
  - `public enum LivePhotoMode: String, Sendable, Codable, CaseIterable { case prompt, downgradeToStill, preservePairing, repairWithFreshID }`.
  - Test: `cd Packages/CleanShareCore && swift build && grep -q 'case repairWithFreshID' Sources/CleanShareCore/Model/LivePhotoMode.swift`.
  - Done: Builds AND all four cases present.
  - Refs: PLAN.md §4.5.

- [ ] **2.04** Define CleanReceipt struct
  - File: `Packages/CleanShareCore/Sources/CleanShareCore/Model/CleanReceipt.swift`.
  - `public struct CleanReceipt: Sendable, Codable, Equatable { public let inputURL: URL; public let outputURL: URL; public let kind: MediaKind; public let bytesIn: Int; public let bytesOut: Int; public let durationMS: Int; public let reencoded: Bool; public let leakedKeys: [String]; public init(...) {...} }` (provide a memberwise `public init`).
  - Test: `cd Packages/CleanShareCore && swift build && grep -q 'public struct CleanReceipt' Sources/CleanShareCore/Model/CleanReceipt.swift`.
  - Done: Builds; struct is `public`.
  - Refs: PLAN.md §4.6.

- [ ] **2.05** Define Cleaner protocol + CleanerError enum
  - `Sources/CleanShareCore/Engine/Cleaner.swift` — `public protocol Cleaner: Sendable { func clean(input: URL, output: URL, prefs: CleaningPreferences) async throws -> CleanReceipt }`.
  - `Sources/CleanShareCore/Engine/CleanerError.swift` — `public enum CleanerError: Error, Sendable, Equatable { case unreadable, unwritable, frameDecodeFailed(index: Int), writeFailed, leakDetected(keys: [String]), appendFailed, avFailed(reason: String?), unsupportedFormat(String), cancelled }`. Use `String?` for `avFailed` rather than `Error?` so the enum is `Sendable + Equatable` without `@unchecked`.
  - These are coupled (`Cleaner.clean` throws `CleanerError`), so they stay in one task.
  - Test: `cd Packages/CleanShareCore && swift build && grep -q 'protocol Cleaner' Sources/CleanShareCore/Engine/Cleaner.swift && grep -q 'case leakDetected' Sources/CleanShareCore/Engine/CleanerError.swift`.
  - Done: Both files exist; package builds.
  - Refs: PLAN.md §4.

- [ ] **2.06** Implement PropertySanitizer helpers
  - File: `Sources/CleanShareCore/Engine/PropertySanitizer.swift` with two `internal` functions per PLAN.md §4.2:
    - `sanitizedFrameProperties(from src: CGImageSource, frameIndex: Int, prefs: CleaningPreferences) -> [CFString: Any]` — explicitly maps each PII dict key to `kCFNull` (one per: `kCGImagePropertyExifDictionary`, `…ExifAuxDictionary`, `…GPSDictionary`, `…IPTCDictionary`, `…TIFFDictionary`, `…JFIFDictionary`, `…MakerAppleDictionary`, `…MakerNikonDictionary`, `…MakerCanonDictionary`, `…MakerFujiDictionary`, `…MakerOlympusDictionary`, `…MakerPentaxDictionary`, `…MakerMinoltaDictionary`, `…PNGDictionary`, `…HEICSDictionary`, plus string-keyed `"{XMP}"`, `"{Photoshop}"`, `"{IPTCXMP}"`). Add-back: root-level orientation if `prefs.keepOrientation`; EXIF sub-dict containing only `kCGImagePropertyExifDateTimeOriginal` if `prefs.keepCaptureDate`.
    - `sanitizedContainerProperties(from src: CGImageSource, prefs: CleaningPreferences) -> [CFString: Any]?` — preserves only structural keys: GIF `kCGImagePropertyGIFLoopCount` if present.
  - Test: `cd Packages/CleanShareCore && swift build && [ "$(grep -c 'kCFNull' Sources/CleanShareCore/Engine/PropertySanitizer.swift)" -ge 15 ]`.
  - Done: Builds; at least 15 `kCFNull` references present.
  - Refs: PLAN.md §4.2, §4.4.

- [ ] **2.07** Implement ImageIOCleaner
  - File: `Sources/CleanShareCore/Engine/ImageIOCleaner.swift` — `public struct ImageIOCleaner: Cleaner` per PLAN.md §4.2 reference implementation, exactly.
  - Mandatory details:
    1. Source opts: `[kCGImageSourceShouldCache: false]`.
    2. Iterate every frame via `CGImageSourceGetCount(src)`.
    3. Always use `CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)` — NEVER `…AddImageFromSource`. SwiftLint rule 1.08 fails the build if you do.
    4. Honour `try Task.checkCancellation()` inside the per-frame loop.
    5. After `CGImageDestinationFinalize`, call `MetadataAuditor.audit(...)`; throw `CleanerError.leakDetected(keys:)` if non-empty.
    6. The function returns a `CleanReceipt` with `reencoded: true` for now (true zero-encode JPEG splicing is a Phase 2 follow-up in PLAN.md §21).
  - Test: `cd Packages/CleanShareCore && swift build && ! grep -rn 'CGImageDestinationAddImageFromSource' Sources/`.
  - Done: Builds; the dangerous symbol does NOT appear in any source file.
  - Refs: PLAN.md §4.2.

- [ ] **2.08** Implement MetadataAuditor (image side)
  - File: `Sources/CleanShareCore/Verification/MetadataAuditor.swift` — `public enum MetadataAuditor { public static func audit(url: URL, kind: MediaKind, allowing: Set<String>) throws -> [String] }`.
  - For image kinds: `CGImageSourceCreateWithURL` → `CGImageSourceCopyPropertiesAtIndex(_, 0, nil)` → compute `SENSITIVE.intersection(props.keys.map(String.init(describing:))).subtracting(allowlist).sorted()`. `SENSITIVE` is the set of dictionary names: `{Exif}`, `{ExifAux}`, `{GPS}`, `{IPTC}`, `{TIFF}`, `{JFIF}`, `{MakerApple}`, `{MakerNikon}`, `{MakerCanon}`, `{MakerFuji}`, `{MakerOlympus}`, `{MakerPentax}`, `{MakerSony}`, `{XMP}`, `{Photoshop}`, `{IPTCXMP}`, `{PNG}`, `{HEICS}`.
  - Video stub returns `[]` here (filled in 3.02).
  - Test: `cd Packages/CleanShareCore && swift build && grep -q 'enum MetadataAuditor' Sources/CleanShareCore/Verification/MetadataAuditor.swift`.
  - Done: Builds; auditor enum exists with the static method.
  - Refs: PLAN.md §8.1.

- [ ] **2.09** Write scripts/make-dirty-fixtures.sh + generate 5 dirty image fixtures
  - File: `scripts/make-dirty-fixtures.sh` (chmod +x). Generates exactly these files in `tests/fixtures/dirty/`:
    1. `iphone_sample.jpg` — 200×200 JPEG with EXIF GPS lat/lon, Make=Apple, Model=iPhone, an Apple MakerNote (use exiftool `-MakerNotes:CameraSerialNumber=ABC123 -EXIF:GPSLatitude='51.5074 N' -EXIF:GPSLongitude='0.1278 W' -EXIF:Make=Apple -EXIF:Model='iPhone 15 Pro' -overwrite_original`).
    2. `pixel_sample.jpg` — 200×200 JPEG with EXIF + XMP (`-EXIF:Make=Google -EXIF:Model=Pixel\ 8 -XMP:Creator=TestUser`).
    3. `transparent.png` — 64×64 transparent PNG with tEXt comment (`exiftool -PNG:Comment='leak this'`).
    4. `animated.gif` — 2-frame GIF with XMP packet (`-XMP:Creator=GIFTester`).
    5. `lightroom.jpg` — 200×200 JPEG with heavy XMP (`-XMP:All='heavy block...' -XMP:Subject='cat,dog'` plus a custom panel).
  - Use `sips` (`sips -s format jpeg --resampleHeightWidth 200 200 src.png -o dst.jpg`) or `ffmpeg` to create the source pixels from an arbitrary 1×1 PNG, then exiftool to inject metadata.
  - Write `tests/fixtures/README.md` listing each file + license (CC0 — synthesized in-house, no source-photo provenance).
  - Test:
    ```bash
    bash scripts/make-dirty-fixtures.sh && \
    for f in iphone_sample.jpg pixel_sample.jpg transparent.png animated.gif lightroom.jpg; do
        test -f "tests/fixtures/dirty/$f" || { echo "missing $f"; exit 1; }
    done && \
    exiftool tests/fixtures/dirty/iphone_sample.jpg | grep -qi 'GPS Latitude' && \
    exiftool tests/fixtures/dirty/pixel_sample.jpg | grep -qi 'Creator' && \
    test -f tests/fixtures/README.md
    ```
  - Done: All five fixtures exist, iphone_sample has GPS, pixel_sample has XMP Creator, README documents provenance.
  - Refs: PLAN.md §8.2, §15.

- [ ] **2.10** Wire fixtures into CleanShareCore test target as resources
  - Update `Packages/CleanShareCore/Package.swift` so `CleanShareCoreTests` target has `resources: [.copy("Fixtures")]` and the directory `Packages/CleanShareCore/Tests/CleanShareCoreTests/Fixtures` is a symlink to `../../../../tests/fixtures/dirty` (relative path). Create the symlink with `ln -sf ../../../../tests/fixtures/dirty Packages/CleanShareCore/Tests/CleanShareCoreTests/Fixtures`.
  - Test: `test -L Packages/CleanShareCore/Tests/CleanShareCoreTests/Fixtures && [ "$(readlink Packages/CleanShareCore/Tests/CleanShareCoreTests/Fixtures)" = "../../../../tests/fixtures/dirty" ] && cd Packages/CleanShareCore && swift build`.
  - Done: Symlink exists pointing at fixtures; package compiles.
  - Refs: PLAN.md §8.2.

- [ ] **2.11** Write ImageIOCleanerTests (one test per fixture, all must show leak-free output)
  - File: `Packages/CleanShareCore/Tests/CleanShareCoreTests/ImageIOCleanerTests.swift`. Five tests: `testJPEGiPhoneSample`, `testJPEGPixelSample`, `testPNGTransparent`, `testGIFAnimated`, `testJPEGLightroom`. Each loads the fixture via `Bundle.module.url(forResource:withExtension:)`, runs `ImageIOCleaner().clean(...)`, then asserts the receipt's `leakedKeys` is empty AND `MetadataAuditor.audit(url: outURL, kind: <kind>, allowing: [])` returns `[]`.
  - Test: `cd Packages/CleanShareCore && swift test --filter ImageIOCleanerTests` — all 5 pass.
  - Done: All five image cleaning tests pass.
  - Refs: PLAN.md §8.2.

- [ ] **2.12** Write scripts/verify-metadata-stripped.sh
  - Accepts one or more file paths. Behaviour:
    - For images (`.jpg`, `.jpeg`, `.heic`, `.heif`, `.png`, `.gif`, `.tiff`, `.webp`): run `exiftool -a -G1 -j <file>` and `jq` over the result asserting that the EXIF, GPS, IPTC, XMP, Photoshop, and any MakerNotes top-level group keys are absent or empty. Print which key leaked and exit 1 on any positive match.
    - For videos (`.mp4`, `.mov`): run `ffprobe -v error -show_format -show_streams -of json <file>` and `jq` over `.format.tags // {}, .streams[].tags // {}` asserting both empty.
  - `chmod +x`. Outputs `OK <file>` on success.
  - Test: `test -x scripts/verify-metadata-stripped.sh && bash -n scripts/verify-metadata-stripped.sh && bash scripts/verify-metadata-stripped.sh tests/fixtures/dirty/iphone_sample.jpg; [ $? -ne 0 ]` (the dirty fixture MUST trigger a leak detection).
  - Done: Script parses; running it on a dirty fixture exits non-zero (it correctly DETECTS the leak we expect to be there pre-cleaning).
  - Refs: PLAN.md §8.3.

- [ ] **2.13** Write scripts/check-no-trackers.sh
  - Greps `App/`, `ShareExtension/`, `Packages/CleanShareCore/Sources/`, `Packages/CleanShareUI/Sources/` (if exists) for any of: `Firebase`, `Mixpanel`, `Amplitude`, `Sentry`, `Bugsnag`, `Crashlytics`, `FBSDK`, `FacebookCore`, `AppsFlyer`, `Branch.io`. Case-insensitive. Excludes comments inside `// FORBIDDEN:` lines (so docs can mention the names).
  - Also greps the built `.app` (if `find ~/Library/Developer/Xcode/DerivedData -name 'CleanShare.app' -type d -path '*/Debug-iphonesimulator/*' | head -1` finds one) using `strings` for the same set.
  - Exits non-zero on any match.
  - Test: `test -x scripts/check-no-trackers.sh && bash -n scripts/check-no-trackers.sh && bash scripts/check-no-trackers.sh`.
  - Done: Script is executable, syntax-checks, and exits 0 on the current (empty) source tree.
  - Refs: PLAN.md §8.6, §18.3.

- [ ] **2.14** Add CleanShareCoreCLI executable target + wire `make verify-strip`
  - Edit `Packages/CleanShareCore/Package.swift`: add `.executableTarget(name: "cleanshare-cli", dependencies: ["CleanShareCore"], path: "Sources/CleanShareCoreCLI")` AND add `cleanshare-cli` to `products`.
  - Create `Packages/CleanShareCore/Sources/CleanShareCoreCLI/main.swift`. CLI usage: `cleanshare-cli clean <input> <output> [--kind=auto|jpeg|heic|…]`. On error, exit non-zero with `stderr` message.
  - Update Makefile `verify-strip`:
    ```makefile
    verify-strip:
    \tcd Packages/CleanShareCore && swift build --product cleanshare-cli
    \trm -rf tests/fixtures/cleaned && mkdir -p tests/fixtures/cleaned
    \tfor f in tests/fixtures/dirty/*; do \\
    \t  ./Packages/CleanShareCore/.build/debug/cleanshare-cli clean "$$f" "tests/fixtures/cleaned/$$(basename $$f)" || exit 1; \\
    \tdone
    \tbash scripts/verify-metadata-stripped.sh tests/fixtures/cleaned/*
    ```
  - Test: `make verify-strip` exits 0.
  - Done: All fixtures clean AND post-clean audit reports OK for every file.
  - Refs: PLAN.md §8.3.

- [ ] **2.15** Wire privacy-regression job into pr.yml + commit Phase 2
  - Extend `.github/workflows/pr.yml` with a `privacy-regression` job (parallel to the validate job): same macOS 15 runner, `brew install exiftool ffmpeg`, run `cd Packages/CleanShareCore && swift test`, then `make verify-strip`.
  - Validate: `python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/pr.yml')); assert 'privacy-regression' in d['jobs']"`.
  - Commit message: `feat(engine): phase 2 — image cleaner + auditor + 5 fixtures + privacy CI gate`.
  - Test: `python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/pr.yml')); assert 'privacy-regression' in d['jobs']" && grep -q verify-strip .github/workflows/pr.yml && git log --oneline -1 | grep -q 'phase 2'`.
  - Done: Workflow has the new job AND the commit is recorded.
  - Refs: PLAN.md §11.1.

---

## Phase 3: Video + Live Photo + share-extension wiring

- [ ] **3.01** Implement AVPassthroughCleaner (passthrough writer)
  - File: `Sources/CleanShareCore/Engine/AVPassthroughCleaner.swift` — `public struct AVPassthroughCleaner: Cleaner`. Implementation must match PLAN.md §4.3 exactly:
    1. `AVURLAsset(url: input, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])`.
    2. `let writer = try AVAssetWriter(outputURL: output, fileType: output.pathExtension.lowercased() == "mov" ? .mov : .mp4)`; `writer.shouldOptimizeForNetworkUse = true`; `writer.metadata = []`.
    3. For each track: skip `.metadata` and `.text`. Otherwise add an `AVAssetReaderTrackOutput(track: …, outputSettings: nil)` (with `alwaysCopiesSampleData = false`) and an `AVAssetWriterInput(mediaType: track.mediaType, outputSettings: nil, sourceFormatHint: track.formatDescriptions.first!)`. Set `input.metadata = []` and `input.expectsMediaDataInRealTime = false`.
    4. Start reader and writer; `writer.startSession(atSourceTime: .zero)`.
    5. Pump samples per track via `withTaskGroup` + `requestMediaDataWhenReady(on: queue) { … }` wrapped in a `withCheckedThrowingContinuation`.
    6. After pump completes, `await writer.finishWriting()`. If status != `.completed`, throw `CleanerError.avFailed(reason: writer.error?.localizedDescription)`.
    7. Honour `try Task.checkCancellation()` inside the pump loop (on `kill the writer with cancelWriting()` if cancellation is detected).
  - If Swift 6 concurrency complains about `AVAssetWriterInput` not being `Sendable`, isolate it inside a single Task — do not cross `await` boundaries with the writer. One `@unchecked Sendable` wrapper IS acceptable here with a documented comment citing PLAN.md §7.2.
  - Test: `cd Packages/CleanShareCore && swift build`.
  - Done: Builds without warnings.
  - Refs: PLAN.md §4.3, §7.

- [ ] **3.02** Extend MetadataAuditor for video
  - Replace the video stub returning `[]`. New behaviour: load the asset, await `.commonMetadata` AND `.metadata`, then iterate every track's `.metadata`. Build a set of `AVMetadataItem` `.key` strings (case `"\(item.identifier?.rawValue ?? "")"`).
  - Sensitive identifiers (any of these in the output is a leak):
    - `mdta/com.apple.quicktime.location.ISO6709`
    - `mdta/com.apple.quicktime.creationdate`
    - `mdta/com.apple.quicktime.make`
    - `mdta/com.apple.quicktime.model`
    - `mdta/com.apple.quicktime.software`
    - `mdta/com.apple.quicktime.content.identifier` (unless allowlist contains it — used by Live Photo `.preservePairing`)
    - `udta/©xyz` (legacy GPS atom)
    - Any timed-metadata track being present at all.
  - Return the sensitive keys that ARE present and NOT in `allowing`.
  - Test: `cd Packages/CleanShareCore && swift build && grep -q 'commonMetadata' Sources/CleanShareCore/Verification/MetadataAuditor.swift && grep -q 'ISO6709' Sources/CleanShareCore/Verification/MetadataAuditor.swift`.
  - Done: Builds; both string references present.
  - Refs: PLAN.md §4.3, §8.1.

- [ ] **3.03** Generate the video fixture
  - Add `scripts/make-dirty-fixtures.sh` step (extend the file from 2.09) that produces `tests/fixtures/dirty/h264_short.mp4`:
    ```bash
    ffmpeg -y -f lavfi -i 'testsrc=duration=2:size=320x240:rate=30' \
      -c:v libx264 -pix_fmt yuv420p \
      -metadata location='+51.5074-000.1278/' \
      -metadata 'com.apple.quicktime.make=Apple' \
      -metadata 'com.apple.quicktime.model=iPhone 15 Pro' \
      tests/fixtures/dirty/h264_short.mp4
    ```
  - Verify the location atom IS present BEFORE cleaning: `ffprobe -v error -show_format tests/fixtures/dirty/h264_short.mp4 -of json | python3 -c "import json,sys; d=json.load(sys.stdin); tags=d['format'].get('tags',{}); assert 'location' in tags or any('location' in k.lower() for k in tags), tags"`.
  - Test: `bash scripts/make-dirty-fixtures.sh && test -f tests/fixtures/dirty/h264_short.mp4 && ffprobe -v error tests/fixtures/dirty/h264_short.mp4 -show_format -of json | grep -qi location`.
  - Done: Fixture exists; ffprobe confirms a location-related tag is present in the input.
  - Refs: PLAN.md §8.2.

- [ ] **3.04** Write AVPassthroughCleanerTests
  - File: `Tests/CleanShareCoreTests/AVPassthroughCleanerTests.swift`. Two tests:
    1. `testH264PassthroughStripsAllMetadata` — clean `h264_short.mp4`, assert `receipt.leakedKeys.isEmpty` AND `MetadataAuditor.audit(url: out, kind: .mp4, allowing: [])` returns `[]`.
    2. `testH264PassthroughDoesNotReencode` — assert output file size is within ±15% of input size (more generous than PLAN's ±10% because `shouldOptimizeForNetworkUse = true` reorganises atoms). Also assert `receipt.reencoded == false`.
  - Test: `cd Packages/CleanShareCore && swift test --filter AVPassthroughCleanerTests`.
  - Done: Both tests pass.
  - Refs: PLAN.md §4.3, §8.2.

- [ ] **3.05** Implement Workspace actor
  - File: `Sources/CleanShareCore/IO/Workspace.swift` — `public actor Workspace`. API:
    - `public init(appGroupID: String) throws` — resolves the App Group container via `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`. If `nil` (e.g. running unit tests where the app group isn't entitled), fall back to `NSTemporaryDirectory()/CleanShareWorkspace/`. Document the fallback.
    - `public func newJob() throws -> JobURLs` (synchronous body inside the actor, returns `JobURLs` with `id: UUID`, `inDir`, `outDir`, `manifestURL`). Create the directory tree.
    - `public func cleanup(jobID: UUID) throws` — removes `tmp/job-<id>` recursively.
    - `public func cleanupExpired(olderThan ttl: TimeInterval) throws` — walks `tmp/job-*` and `inbox/*`, removes anything whose creation date is older than `Date().addingTimeInterval(-ttl)`.
  - Mark `JobURLs` `public struct Sendable`.
  - Test: write `Tests/CleanShareCoreTests/WorkspaceTests.swift` with one test creating two jobs, asserting their dirs exist, cleaning one, then `cleanupExpired(olderThan: 0)` removes everything. Run `cd Packages/CleanShareCore && swift test --filter WorkspaceTests`.
  - Done: Test passes.
  - Refs: PLAN.md §5.3, §3.1.

- [ ] **3.06** Implement MemoryWatchdog actor
  - File: `Sources/CleanShareCore/Concurrency/MemoryWatchdog.swift` — `public actor MemoryWatchdog`. API:
    - `public init(pollInterval: Duration = .milliseconds(250))`.
    - `public func footprintMB() async -> Int` — reads `mach_task_basic_info` via `task_info(mach_task_self_, MACH_TASK_BASIC_INFO, …)`; converts `resident_size` to MB.
    - `public func start() -> AsyncStream<MemoryEvent>` — long-lived `Task` polling every interval, yielding `.warning(mb:)` once when footprint first exceeds 80, `.critical(mb:)` once when first exceeds 90. Does NOT re-emit the same event twice in a row.
    - `public func stop()` — cancels the polling task.
  - `public enum MemoryEvent: Sendable, Equatable { case warning(mb: Int); case critical(mb: Int) }`.
  - Test: `cd Packages/CleanShareCore && swift build && swift test --filter MemoryWatchdogBasicTest` (write one test that just instantiates and reads `footprintMB()` — > 0).
  - Done: Builds; basic test passes.
  - Refs: PLAN.md §5.1.

- [ ] **3.07** Implement LivePhotoCleaner
  - File: `Sources/CleanShareCore/Engine/LivePhotoCleaner.swift` — `public struct LivePhotoCleaner: Sendable`. Method: `public func clean(still: URL, video: URL, outDir: URL, mode: LivePhotoMode, prefs: CleaningPreferences) async throws -> (still: CleanReceipt, video: CleanReceipt?)`.
  - Implementation per PLAN.md §4.5:
    - Resolve mode: if mode == `.prompt`, this is a programmer error — engine should never receive `.prompt`. Throw `CleanerError.unsupportedFormat("LivePhotoMode.prompt must be resolved by UI")`.
    - Read source UUID: from the still via `kCGImagePropertyMakerAppleDictionary` key `"17"`; from the video via `AVMetadataItem` with `identifier == "mdta/com.apple.quicktime.content.identifier"`.
    - `.downgradeToStill` — clean only the still via `ImageIOCleaner`. Discard the video. Force the still's allowlist to exclude `MakerApple`.
    - `.preservePairing` — clean both. The still's allowlist allows MakerApple key 17 only; the video's allowlist allows `com.apple.quicktime.content.identifier`. Re-inject the SAME original UUID into both outputs.
    - `.repairWithFreshID` — generate `let newID = UUID().uuidString`. Clean both. Inject `newID` into both outputs.
  - Add helper `internal func injectContentIdentifier(_ id: String, into videoURL: URL) throws` that uses `AVAssetWriter` (or re-mux via `AVAssetExportSession` with a metadata pass — the simpler approach is to mutate in-place via writing a new file and atomic-rename).
  - Test: `cd Packages/CleanShareCore && swift build`.
  - Done: Builds. (End-to-end test happens in 3.08.)
  - Refs: PLAN.md §4.5.

- [ ] **3.08** Write LivePhotoCleanerTests (synthetic pair)
  - Extend `scripts/make-dirty-fixtures.sh` to also produce a synthetic Live Photo pair: `tests/fixtures/dirty/livephoto.heic` (use exiftool to set `MakerNotes:ContentIdentifier=ABC-123-DEADBEEF`) and `tests/fixtures/dirty/livephoto.mov` (use ffmpeg `-metadata com.apple.quicktime.content.identifier=ABC-123-DEADBEEF`).
  - File: `Tests/CleanShareCoreTests/LivePhotoCleanerTests.swift`. Three tests:
    1. `testDowngradeProducesOnlyStillAndDropsUUID` — out has only the still file; auditor reports no leak; the still's MakerApple dict is absent.
    2. `testPreservePairingKeepsUUIDInBoth` — both files produced; both contain the SAME UUID (`ABC-123-DEADBEEF`); no other metadata leaks.
    3. `testRepairWithFreshIDInjectsNewUUID` — both files produced; both contain the same NEW UUID; that UUID is NOT `ABC-123-DEADBEEF`.
  - Test: `cd Packages/CleanShareCore && swift test --filter LivePhotoCleanerTests`.
  - Done: All three tests pass.
  - Refs: PLAN.md §4.5, §8.2.

- [ ] **3.09** Implement Manifest types
  - File: `Sources/CleanShareCore/IO/Manifest.swift`. Types:
    - `public struct Manifest: Codable, Sendable, Equatable { public let token: String; public let createdAt: Date; public let receipts: [CleanReceipt]; public init(token: String, receipts: [CleanReceipt]) { self.token = token; self.createdAt = Date(); self.receipts = receipts } }`.
    - `public enum ManifestWriter { public static func write(_ manifest: Manifest, to url: URL) throws { let data = try JSONEncoder().encode(manifest); try data.write(to: url, options: .atomic) } }`.
    - `public enum ManifestReader { public static func read(from url: URL) throws -> Manifest { let data = try Data(contentsOf: url); return try JSONDecoder().decode(Manifest.self, from: data) } }`.
  - Test: write `Tests/CleanShareCoreTests/ManifestTests.swift` with one round-trip test (write then read; assert equality). Run `cd Packages/CleanShareCore && swift test --filter ManifestTests`.
  - Done: Round-trip test passes.
  - Refs: PLAN.md §6.

- [ ] **3.10** Implement HandoffURL helpers
  - File: `Sources/CleanShareCore/IO/HandoffURL.swift`. Extension:
    ```swift
    public extension URL {
        static func handoff(token: String) -> URL {
            var c = URLComponents()
            c.scheme = "cleanshare"
            c.host = "handoff"
            c.queryItems = [URLQueryItem(name: "t", value: token)]
            return c.url!
        }

        static func handoffToken(from url: URL) -> String? {
            guard url.scheme == "cleanshare", url.host == "handoff" else { return nil }
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "t" })?.value
        }
    }
    ```
  - Test: write `Tests/CleanShareCoreTests/HandoffURLTests.swift` with `testRoundTrip` (build URL with token "abc-123", parse it back, assert equality) and `testRejectsForeignScheme` (`URL(string: "https://evil.com")?` parses to nil). Run `swift test --filter HandoffURLTests`.
  - Done: Both tests pass.
  - Refs: PLAN.md §6.

- [ ] **3.11** Implement CleaningPipeline actor
  - File: `Sources/CleanShareCore/Engine/CleaningPipeline.swift` per PLAN.md §4.6 and §7.3.
  - `public actor CleaningPipeline`. API:
    - `public init(workspace: Workspace, prefs: CleaningPreferences, maxConcurrent: Int = 2)`.
    - `public func enqueue(_ items: [InputItem])` — `InputItem = (id: UUID, sourceURL: URL, kind: MediaKind)`.
    - `public func run() -> AsyncThrowingStream<CleanEvent, Error>` — bounded `withDiscardingTaskGroup` per PLAN.md §7.3.
    - `public func cancel() async` — sets a cancellation flag; ongoing cleaners get `Task.checkCancellation()`.
  - `public enum CleanEvent: Sendable { case progress(itemID: UUID, fraction: Double); case completed(itemID: UUID, receipt: CleanReceipt); case failed(itemID: UUID, error: CleanerError) }`.
  - Pick the right cleaner per `MediaKind`: image kinds → `ImageIOCleaner`, video kinds → `AVPassthroughCleaner`, `.livePhoto` → `LivePhotoCleaner` (will be a `livePhoto` InputItem variant in a future task — for now reject with `.unsupportedFormat`).
  - Test: write `Tests/CleanShareCoreTests/CleaningPipelineTests.swift` with `testProcessesThreeImagesAndYieldsThreeCompletedEvents`. Use the 5 image fixtures from 2.09; enqueue 3 of them; collect events; assert exactly 3 `.completed` events and 0 `.failed`. Run `swift test --filter CleaningPipelineTests`.
  - Done: Test passes — three images cleaned, three events received.
  - Refs: PLAN.md §4.6, §7.3.

- [ ] **3.12** Create CleanShareUI Swift Package
  - `Packages/CleanShareUI/Package.swift` — swift-tools-version 6.0, platforms `.iOS(.v17)`, products `CleanShareUI` library, depends on local path `../CleanShareCore`.
  - `Packages/CleanShareUI/Sources/CleanShareUI/Placeholder.swift` — `public enum CleanShareUI { public static let version = "0.0.0" }`.
  - `Packages/CleanShareUI/Tests/CleanShareUITests/PlaceholderTests.swift` — one test asserting `CleanShareUI.version` is non-empty.
  - Test: `cd Packages/CleanShareUI && swift build && swift test --filter PlaceholderTests`.
  - Done: Package builds and the placeholder test passes.
  - Refs: PLAN.md §2.

- [ ] **3.13** Add CleanShareUI as a project.yml dependency for both targets
  - Edit `project.yml`: under `packages:`, add `CleanShareUI: { path: Packages/CleanShareUI }`. Under both `CleanShare` and `CleanShareShareExt` targets, add `{ package: CleanShareUI }` to `dependencies`. Re-run `./scripts/generate-project.sh`.
  - Test: `./scripts/generate-project.sh && xcodebuild -project CleanShare.xcodeproj -showBuildSettings -scheme CleanShare 2>&1 | grep -q CleanShareUI`.
  - Done: Both targets link the new package.
  - Refs: PLAN.md §2.

- [ ] **3.14** Implement a minimal CleaningProgressView in CleanShareUI
  - File: `Packages/CleanShareUI/Sources/CleanShareUI/Sheets/CleaningProgressView.swift` — `public struct CleaningProgressView: View`. Takes `@ObservedObject var progress: CleaningProgressModel` where `CleaningProgressModel: ObservableObject` exposes `@Published var fraction: Double` and `@Published var currentFile: String?`. Renders a `VStack` with `ProgressView(value: fraction)`, a `Text(currentFile ?? "Preparing…")`, and a small "Cleaning your media…" heading.
  - Test: `cd Packages/CleanShareUI && swift build && grep -q 'CleaningProgressView' Sources/CleanShareUI/Sheets/CleaningProgressView.swift`.
  - Done: Builds.
  - Refs: PLAN.md §3.1, §6.

- [ ] **3.15** Wire ShareExtension/ShareViewController (real flow)
  - Replace the stub in `ShareExtension/ShareViewController.swift` with the real flow per PLAN.md §3.1 + §6:
    1. `viewDidLoad`: create a `CleaningProgressModel`, host `CleaningProgressView(progress: model)` via `UIHostingController`, add it as child controller.
    2. Spawn a `Task`:
       - Open a `Workspace(appGroupID: "group.dev.cleanshare.app")`. Allocate a `JobURLs`.
       - Enumerate `extensionContext?.inputItems` → `NSItemProvider` → for each one, call `loadFileRepresentation(forTypeIdentifier:)`. Hardlink (`FileManager.default.linkItem(at:to:)`) into `jobURLs.inDir`. If hardlink fails across volumes, fall back to `copyItem`.
       - Determine `MediaKind` per file via UTI.
       - Build a `CleaningPipeline`, enqueue items, iterate the event stream — update `model.fraction` from `.progress` events; record cleaned URLs from `.completed`.
       - After all items done, write a `Manifest` to `inbox/<token>/manifest.json` via `ManifestWriter`.
       - Call `extensionContext.open(URL.handoff(token: token)) { ok in ... }`. If `ok == true`, call `completeRequest(returningItems: nil)`. Else present a `UIDocumentPickerViewController(forExporting: cleanedURLs)` as the fallback.
    3. Handle cancellation: a "Cancel" button in the progress view calls `pipeline.cancel()` and `extensionContext.cancelRequest(withError: ...)`.
  - Test: `./scripts/generate-project.sh && xcodebuild -project CleanShare.xcodeproj -scheme CleanShareShareExt -destination 'generic/platform=iOS Simulator' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO | xcbeautify --renderer terminal`.
  - Done: Extension target builds — `** BUILD SUCCEEDED **`.
  - Refs: PLAN.md §3.1, §6.

- [ ] **3.16** Wire HandoffRouter (real flow) + ShareSheetCoordinator
  - Replace the stub `HandoffRouter.handle` from 1.15. New behaviour:
    - Parse the token via `URL.handoffToken(from:)`.
    - Read the manifest via `ManifestReader.read(from: appGroup/inbox/<token>/manifest.json)`. If the file doesn't exist or parsing fails, return `false` silently (user-visible error in `RootView` via a transient banner — not a crash).
    - Otherwise build `[URL]` from receipts. Post them on a shared `@MainActor` `ShareSheetCoordinator: ObservableObject` (in `App/Handoff/ShareSheetCoordinator.swift`) — `@Published var pendingURLs: [URL]?`.
    - Schedule cleanup: after 60 s, delete `inbox/<token>` and the original `tmp/job-*` files.
  - `App/Views/RootView.swift` observes the coordinator; presents `UIActivityViewController(activityItems: urls, applicationActivities: nil)` via a `UIViewControllerRepresentable` sheet bound to `pendingURLs != nil`.
  - Test: `./scripts/generate-project.sh && xcodebuild -project CleanShare.xcodeproj -scheme CleanShare -destination 'generic/platform=iOS Simulator' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO | xcbeautify --renderer terminal`.
  - Done: App target builds.
  - Refs: PLAN.md §6.

- [ ] **3.17** Simulator smoke test: app accepts cleanshare:// URL without crashing
  - 1. `mcp__ios-simulator__open_simulator`; `mcp__ios-simulator__get_booted_sim_id` → record UDID.
  - 2. `find ~/Library/Developer/Xcode/DerivedData -name 'CleanShare.app' -path '*/Debug-iphonesimulator/*' -type d | head -1` to resolve `.app`. `mcp__ios-simulator__install_app`. `mcp__ios-simulator__launch_app dev.cleanshare.app`.
  - 3. Capture pre-URL screenshot: `mcp__ios-simulator__screenshot` → `screenshots/dev/3.17-pre-url.png`.
  - 4. Open URL via bash: `xcrun simctl openurl <UDID> "cleanshare://handoff?t=nonexistent"`.
  - 5. Wait 2 s. `mcp__ios-simulator__screenshot` → `screenshots/dev/3.17-post-url.png`. `mcp__ios-simulator__ui_describe_all` and confirm "CleanShare" is still visible (the app did NOT crash; it gracefully ignored the missing manifest).
  - Visual Check: post-URL screenshot still shows the RootView with the "CleanShare" title; no system crash dialog overlays; no blank black screen.
  - Test: `test -f screenshots/dev/3.17-pre-url.png && test -f screenshots/dev/3.17-post-url.png && [ "$(stat -f %z screenshots/dev/3.17-post-url.png 2>/dev/null || stat -c %s screenshots/dev/3.17-post-url.png)" -gt 10000 ]`.
  - Done: Both screenshots exist; post-URL screenshot is >10 KB and visually shows the app still alive.
  - Refs: PLAN.md §6.

- [ ] **3.18** Commit Phase 3
  - Stage: `git add Packages/CleanShareCore/ Packages/CleanShareUI/ ShareExtension/ App/ project.yml scripts/make-dirty-fixtures.sh tests/fixtures/dirty/h264_short.mp4 tests/fixtures/dirty/livephoto.* tests/fixtures/README.md`.
  - Commit message: `feat(engine,extension): phase 3 — video passthrough + live photo + share-extension wiring + handoff router`.
  - Test: `git log --oneline -1 | grep -q 'phase 3'`.
  - Done: Commit recorded.
  - Refs: PLAN.md §20 Week 3.

---

## Phase 4: UI polish

- [ ] **4.01** Implement CleaningPreferencesStore (ObservableObject backing Settings + onboarding)
  - File: `Packages/CleanShareUI/Sources/CleanShareUI/Stores/CleaningPreferencesStore.swift` — `@MainActor public final class CleaningPreferencesStore: ObservableObject`. Uses `UserDefaults(suiteName: "group.dev.cleanshare.app")` as backing store. `@Published` properties matching `CleaningPreferences` fields. Provides a `var current: CleaningPreferences { get set }` computed property that synthesizes a snapshot from the published values.
  - Also store `onboardingCompletedV1: Bool` and `LivePhotoDefaultMode: LivePhotoMode?` as backing keys.
  - Test: `cd Packages/CleanShareUI && swift build && swift test --filter CleaningPreferencesStoreTests` (one test: init, mutate a flag, re-init from same suite, observe the value persisted).
  - Done: Builds; the persistence round-trip test passes.
  - Refs: PLAN.md §4.5, §4.6.

- [ ] **4.02** Implement OnboardingView (3 pages)
  - File: `Packages/CleanShareUI/Sources/CleanShareUI/Onboarding/OnboardingView.swift` — `public struct OnboardingView: View`. Body: `TabView` with `.tabViewStyle(.page)`, three pages:
    1. **Welcome** — large headline "Share without leaking" + subhead "CleanShare strips identifying metadata from your photos and videos before sharing them" + an SF Symbol icon `lock.shield.fill` in teal `#19B4B0`.
    2. **How** — three-step illustration: "1. Share from Photos → 2. CleanShare cleans → 3. Share to anyone". Use SF Symbols `square.and.arrow.up`, `wand.and.stars`, `paperplane.fill`.
    3. **Privacy** — bullet list: "No accounts. No analytics. No network. Source open at github.com/<placeholder>/cleanshare." + a primary "Get started" button that sets `prefsStore.onboardingCompletedV1 = true` and dismisses.
  - Each page uses a vertical gradient background `LinearGradient(colors: [Color(red: 0.098, green: 0.706, blue: 0.690), Color(red: 0.231, green: 0.247, blue: 0.722)], startPoint: .top, endPoint: .bottom)` (= teal → indigo from PLAN.md §14.2).
  - Test: `cd Packages/CleanShareUI && swift build`.
  - Done: Builds; `OnboardingView` is `public`.
  - Refs: PLAN.md §14.2, §20 Week 4.

- [ ] **4.03** Wire OnboardingView into RootView (first launch only)
  - In `App/Views/RootView.swift`, observe `@StateObject var prefsStore = CleaningPreferencesStore()`. If `prefsStore.onboardingCompletedV1 == false`, present `OnboardingView` as a `.fullScreenCover`. Otherwise show the main UI (currently the placeholder Text — primary content comes in later tasks).
  - Test: `xcodebuild -project CleanShare.xcodeproj -scheme CleanShare -destination 'generic/platform=iOS Simulator' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`.
  - Done: Builds.
  - Refs: PLAN.md §20 Week 4.

- [ ] **4.04** Sim verify onboarding page 1 — visual inspection
  - 1. `xcrun simctl uninstall <UDID> dev.cleanshare.app` to clear stored prefs (so onboarding shows).
  - 2. Build + install + launch via the MCP tools.
  - 3. `mcp__ios-simulator__screenshot` → `screenshots/dev/4.04-onboarding-1.png`.
  - 4. `mcp__ios-simulator__ui_describe_all` — confirm strings "Share without leaking" and "Get started" (or "Next") visible.
  - Visual Check (LOOK at the screenshot):
    1. Teal-to-indigo vertical gradient renders smoothly (no banding visible).
    2. The white SF Symbol shield icon is centered horizontally.
    3. Headline "Share without leaking" is large, white, readable.
    4. Subhead is below the headline in a smaller font, still readable.
    5. Page indicator dots near the bottom (3 dots, first one filled).
    6. No clipped text, no system error overlays.
  - If anything looks wrong (wrong colors, broken layout), fix `OnboardingView.swift` and re-capture.
  - Test: `test -f screenshots/dev/4.04-onboarding-1.png && [ "$(stat -f %z screenshots/dev/4.04-onboarding-1.png 2>/dev/null || stat -c %s screenshots/dev/4.04-onboarding-1.png)" -gt 30000 ]` (gradient-rendered PNG should be >30 KB).
  - Done: Screenshot exists AND visual criteria 1–6 are all satisfied.
  - Refs: PLAN.md §14.2.

- [ ] **4.05** Sim verify onboarding pages 2 + 3 + "Get started" dismisses
  - From the booted sim where 4.04 left off: `mcp__ios-simulator__ui_swipe` from right to left to advance to page 2. `screenshot` → `4.05-onboarding-2.png`. Swipe again to page 3. `screenshot` → `4.05-onboarding-3.png`. `ui_find_element` for "Get started"; `ui_tap` it. Then `screenshot` → `4.05-after-onboarding.png`. `ui_describe_all` — confirm the onboarding sheet is gone and the main RootView is visible.
  - Visual Check:
    - 4.05-onboarding-2.png: three-step illustration visible; icons distinct; second page indicator dot filled.
    - 4.05-onboarding-3.png: bullet list legible; "Get started" button is the prominent CTA.
    - 4.05-after-onboarding.png: main RootView visible — NO onboarding overlay remains.
  - Test: `[ "$(ls screenshots/dev/4.05-*.png 2>/dev/null | wc -l)" -eq 3 ] && for f in screenshots/dev/4.05-*.png; do [ "$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f")" -gt 10000 ] || { echo "thin: $f"; exit 1; }; done`.
  - Done: Three screenshots exist (>10 KB each) AND visual criteria above hold.
  - Refs: PLAN.md §14.2.

- [ ] **4.06** Implement SettingsView
  - File: `Packages/CleanShareUI/Sources/CleanShareUI/Settings/SettingsView.swift` — `public struct SettingsView: View`. Use SwiftUI `Form` with sections:
    1. **Metadata to keep** — toggles for `keepOrientation`, `keepICCProfile`, `keepCaptureDate`, `keepCameraMakeModel`, each bound to `prefsStore.*`.
    2. **Location (GPS)** — toggle for `keepGPS`. When the user tries to enable it, show an `.alert` titled "Keep GPS in shared photos?" with body "Photos with GPS coordinates reveal where they were taken. Are you sure?" and Cancel + Enable buttons.
    3. **Live Photos** — `Picker("When sharing Live Photos", selection: ...)` with the four `LivePhotoMode` cases.
    4. **Diagnostics** — toggle "Help improve CleanShare" (default off). Footer text: "When enabled, MetricKit crash reports are stored on-device only. Tap below to export. No automatic upload."  Below the toggle, a `Button("Export Last 5 Crash Reports")` (only enabled when the toggle is on; opens a share sheet — wiring lands in 7.04).
    5. **About** — `NavigationLink("About CleanShare", destination: AboutView())`.
  - Test: `cd Packages/CleanShareUI && swift build`.
  - Done: Builds.
  - Refs: PLAN.md §4.5, §4.6, §9.

- [ ] **4.07** Add Settings entry point in RootView
  - Add a gear icon button in the navigation bar that presents `SettingsView` as a sheet.
  - Test: `xcodebuild ... -scheme CleanShare build ...`.
  - Done: Builds.
  - Refs: PLAN.md §20 Week 4.

- [ ] **4.08** Sim verify SettingsView — every toggle visible + GPS confirmation alert
  - Rebuild + reinstall + launch (skip onboarding by setting prefs first: `xcrun simctl spawn <UDID> defaults write group.dev.cleanshare.app onboardingCompletedV1 -bool YES`).
  - Tap gear icon via `ui_find_element` + `ui_tap`. `screenshot` → `4.08-settings.png`.
  - `ui_describe_all` — confirm the substrings: "Metadata to keep", "Keep orientation", "Keep ICC", "Keep capture date", "Keep camera make", "Location (GPS)", "Live Photos", "Diagnostics", "About CleanShare".
  - Tap the GPS toggle. `screenshot` → `4.08-gps-alert.png`. Confirm the alert appears with "Keep GPS in shared photos?" headline.
  - Tap "Cancel" to dismiss. `screenshot` → `4.08-after-cancel.png` (toggle remains OFF).
  - Visual Check:
    - 4.08-settings.png: a clean `Form` with five sections, every toggle labelled and rendered correctly.
    - 4.08-gps-alert.png: standard iOS alert overlay, title and body visible.
    - 4.08-after-cancel.png: GPS toggle is in the OFF position (visually); no alert.
  - Test: `[ "$(ls screenshots/dev/4.08-*.png 2>/dev/null | wc -l)" -eq 3 ]`.
  - Done: All three screenshots present AND visual criteria above hold.
  - Refs: PLAN.md §4.5.

- [ ] **4.09** Implement AboutView (sections: version + privacy + source + supported formats)
  - File: `Packages/CleanShareUI/Sources/CleanShareUI/About/AboutView.swift` — `public struct AboutView: View`. Use SwiftUI `List` with these sections (titles render as section headers visible in screenshots):
    1. **Header** — large wordmark "CleanShare" + version + build (read from `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` and `["CFBundleVersion"]`). Background uses the brand teal→indigo gradient.
    2. **Zero data collected** — three rows with SF Symbol leading icons: "No accounts" (`person.slash.fill`), "No analytics" (`chart.bar.xaxis.ascending` crossed out), "No network" (`wifi.slash`). Each row has a one-line caption explaining the guarantee. Footer text: "CleanShare never connects to the internet. We test for it on every commit via CI." This section is what's used as the App Store "privacy" screenshot.
    3. **Supported formats** — two rows: "Photos: JPEG, HEIC/HEIF, PNG, GIF, TIFF, WebP" and "Videos: MP4, MOV (H.264, HEVC, ProRes)". Used as the App Store "video support" screenshot.
    4. **Open source (MIT)** — wordmark + "Powered entirely by Apple ImageIO and AVFoundation. Zero third-party SDKs." + a `Link("View source on GitHub", destination: ...)`. Used as the App Store "open source" screenshot.
    5. **Legal** — `Link("Privacy", destination: URL(string: "https://cleanshare.dev/privacy")!)`, `Link("Threat model", destination: URL(string: "https://cleanshare.dev/threat-model")!)`.
  - The source-code URL is read from `Bundle.main.object(forInfoDictionaryKey: "CleanShareSourceURL") as? String ?? "https://github.com/<placeholder>/cleanshare"`. Maintainers override via `Info.plist` build setting.
  - Test: `cd Packages/CleanShareUI && swift build && grep -q 'Zero data collected' Sources/CleanShareUI/About/AboutView.swift && grep -q 'Supported formats' Sources/CleanShareUI/About/AboutView.swift && grep -q 'Open source' Sources/CleanShareUI/About/AboutView.swift`.
  - Done: All three sections present in the source.
  - Refs: PLAN.md §9, §13.5, §14.

- [ ] **4.10** Sim verify AboutView — visual inspection of all four sections
  - From Settings (already open in sim), `ui_find_element "About CleanShare"`, `ui_tap`. `screenshot` → `4.10-about-top.png` (header + zero-data section).
  - `mcp__ios-simulator__ui_swipe` upward to scroll. `screenshot` → `4.10-about-mid.png` (supported formats + open source).
  - Scroll once more. `screenshot` → `4.10-about-bottom.png` (legal links).
  - `ui_describe_all` (run after each scroll) — confirm the strings: "Zero data collected", "No accounts", "No analytics", "No network", "Supported formats", "Photos:", "Videos:", "Open source", "Powered entirely by Apple ImageIO", "View source on GitHub", "Privacy", "Threat model".
  - Visual Check (vision-capable inspection):
    1. Header gradient renders smoothly (no banding).
    2. Version number prominent.
    3. Zero-data section: three rows, each with a leading SF Symbol icon, captions readable.
    4. Supported formats section: two rows with codec lists in monospace or system font.
    5. Open source section has the wordmark + paragraph + GitHub link in iOS link blue.
    6. Legal section: two links (Privacy + Threat model) clearly tappable.
    7. No overflow, no clipped text, no broken layout at any scroll position.
  - Test: `[ "$(ls screenshots/dev/4.10-about-*.png 2>/dev/null | wc -l)" -eq 3 ] && for f in screenshots/dev/4.10-about-*.png; do [ "$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f")" -gt 15000 ] || { echo "thin: $f"; exit 1; }; done`.
  - Done: Three screenshots present, each >15 KB, all visual criteria satisfied.
  - Refs: PLAN.md §9, §13.5.

- [ ] **4.11** Implement LivePhotoConsentSheet
  - File: `Packages/CleanShareUI/Sources/CleanShareUI/Sheets/LivePhotoConsentSheet.swift` — `public struct LivePhotoConsentSheet: View`. Title "Live Photo detected". Body: short explanation of what each mode does (1 line each). Three `Button` rows for the three concrete modes (Downgrade / Preserve / Re-pair), and a `Toggle("Don't ask again", isOn: $dontAskAgain)` at the bottom.
  - On tap of any mode button: if `dontAskAgain == true`, write the chosen mode to `prefsStore.livePhotoDefaultMode`. Then call a `@Binding var onChoose: (LivePhotoMode) -> Void` closure passed by the caller.
  - Test: `cd Packages/CleanShareUI && swift build`.
  - Done: Builds.
  - Refs: PLAN.md §4.5.

- [ ] **4.12** Sim verify LivePhotoConsentSheet via the real PHPicker flow (no debug scaffolding)
  - Seed the simulator's photo library with a synthetic Live Photo pair so the real flow triggers the sheet:
    1. Ensure `tests/fixtures/dirty/livephoto.heic` and `tests/fixtures/dirty/livephoto.mov` exist (created in 3.08).
    2. `xcrun simctl addmedia <UDID> tests/fixtures/dirty/livephoto.heic tests/fixtures/dirty/livephoto.mov`. Verify it imported as a Live Photo via Photos app (sim may import them as separate items — if so, document the limitation in `screenshots/dev/4.12-NOTES.md` and use a fallback path: present the sheet via a `.sheet(isPresented:)` triggered from the in-app "Try it on a Live Photo (sample)" button — see fallback below).
    3. Fallback if (2) doesn't yield a real Live Photo: add a **production** "Try it on a Live Photo (sample)" button to `RootView` (next to "Try it on a sample photo") that ships a bundled `Sample-DirtyLivePhoto.{heic,mov}` pair. This is a real product feature (demonstrating Live Photo support), NOT a debug affordance — it stays in the shipped app.
  - Drive the UI: tap "Clean photos…" → pick the Live Photo (or tap "Try it on a Live Photo (sample)" via the fallback) → the consent sheet appears (because `livePhotoMode == .prompt` is the default).
  - `screenshot` → `screenshots/dev/4.12-livephoto-sheet.png`. `ui_describe_all` — confirm "Downgrade", "Preserve", "Re-pair", "Don't ask again" all visible.
  - Visual Check:
    1. Modal sheet visually distinct from underlying RootView.
    2. Title "Live Photo detected" prominent.
    3. Three mode-choice rows clearly separated, each with a 1-line caption explaining the trade-off.
    4. "Don't ask again" toggle present at the bottom.
    5. No `#if DEBUG` "(debug)" label anywhere — this view is reachable only through real user flows.
  - Test: `test -f screenshots/dev/4.12-livephoto-sheet.png && ! grep -rE '#if DEBUG.*\(debug\)' Packages/CleanShareUI/Sources/ App/ ShareExtension/`.
  - Done: Screenshot exists AND grep confirms no `(debug)`-labelled UI affordances exist in source.
  - Refs: PLAN.md §4.5.

- [ ] **4.13** Generate app icon placeholder (1024×1024)
  - File: `scripts/generate-icons.sh` (chmod +x). Implementation:
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    cd "$(dirname "$0")/.."
    OUT=App/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png
    mkdir -p "$(dirname "$OUT")"
    python3 - "$OUT" <<'PY'
    import sys
    from PIL import Image, ImageDraw, ImageFont
    size = 1024
    img = Image.new("RGB", (size, size))
    for y in range(size):
        t = y / (size - 1)
        r = int(0.098 * (1 - t) * 255 + 0.231 * t * 255)
        g = int(0.706 * (1 - t) * 255 + 0.247 * t * 255)
        b = int(0.690 * (1 - t) * 255 + 0.722 * t * 255)
        for x in range(size):
            img.putpixel((x, y), (r, g, b))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 480)
    except Exception:
        font = ImageFont.load_default()
    text = "CS"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((size - tw) / 2 - bbox[0], (size - th) / 2 - bbox[1]), text,
              fill=(255, 255, 255), font=font)
    img.save(sys.argv[1], "PNG", optimize=True)
    PY
    ```
  - If PIL is missing, run `python3 -m pip install --user Pillow` before re-running.
  - Update `App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` to reference the file: `{"images": [{"filename": "Icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"version": 1, "author": "xcode"}}`.
  - Test: `bash scripts/generate-icons.sh && file App/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png | grep -q '1024 x 1024' && python3 -c "import json; d=json.load(open('App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json')); assert any(i.get('filename')=='Icon-1024.png' for i in d['images'])"`.
  - Done: 1024×1024 PNG exists AND Contents.json references it.
  - Refs: PLAN.md §14.1.

- [ ] **4.14** Add bundled Sample-DirtyPhoto.jpg
  - Copy `tests/fixtures/dirty/iphone_sample.jpg` to `App/Resources/Sample-DirtyPhoto.jpg`. (Keep as JPEG, not HEIC — HEIC conversion via `sips` is unreliable across macOS versions; JPEG is universally supported and the metadata-stripping demo works identically.)
  - Add a one-line `App/Resources/README.md` documenting the file's purpose.
  - Test: `test -f App/Resources/Sample-DirtyPhoto.jpg && exiftool App/Resources/Sample-DirtyPhoto.jpg | grep -qi 'GPS'`.
  - Done: Bundled file present AND has GPS metadata.
  - Refs: PLAN.md §3.3.

- [ ] **4.15** Implement SampleDiffView (BEFORE / AFTER EXIF columns)
  - File: `Packages/CleanShareUI/Sources/CleanShareUI/Sheets/SampleDiffView.swift` — `public struct SampleDiffView: View`. Takes `let beforeURL: URL` and `let afterURL: URL?`.
  - Body: a horizontally split (`HStack`) view with two `ScrollView { Text(...) }` columns. Each column renders the output of `CGImageSourceCopyPropertiesAtIndex(_, 0, nil)` (or `[:]` for the missing case) formatted as `key: value` lines in `.font(.system(.caption, design: .monospaced))`. Colour-code keys that match the SENSITIVE set in red.
  - Title bar: `Text("Before").bold()` left column, `Text("After cleaning").bold()` right column.
  - Test: `cd Packages/CleanShareUI && swift build`.
  - Done: Builds.
  - Refs: PLAN.md §3.3.

- [ ] **4.16** Wire "Try it on a sample photo" button + flow in RootView
  - In `App/Views/RootView.swift`, add a `Button("Try it on a sample photo")`. Tapping:
    1. Copies the bundled `Sample-DirtyPhoto.jpg` into a fresh Workspace job dir's `in/`.
    2. Runs `ImageIOCleaner` cleaning it into the job dir's `out/`.
    3. Presents `SampleDiffView(beforeURL: in, afterURL: out)` as a `.sheet`.
  - Test: `xcodebuild ... -scheme CleanShare build ...`.
  - Done: Builds.
  - Refs: PLAN.md §3.3.

- [ ] **4.17** Sim verify "Try it on a sample photo" — BEFORE has GPS, AFTER does not
  - From RootView (sim already running): `ui_find_element "Try it on a sample photo"` → `ui_tap`. Wait 1 s for cleaning. `screenshot` → `4.17-sample-diff.png`. `ui_describe_all` and confirm:
    - The left column (BEFORE) contains substring "GPS" (red-highlighted) AND substring "Apple" (Make/Model).
    - The right column (AFTER) does NOT contain "GPS" AND does NOT contain "MakerApple".
  - Visual Check (LOOK at the screenshot):
    1. Two side-by-side text columns clearly separated by a vertical divider.
    2. "Before" / "After cleaning" headers visible at the tops.
    3. GPS / MakerApple lines in the BEFORE column visually highlighted (red text or red background).
    4. AFTER column noticeably shorter / sparser than BEFORE column.
    5. Monospaced font.
  - Test: `test -f screenshots/dev/4.17-sample-diff.png && [ "$(stat -f %z screenshots/dev/4.17-sample-diff.png 2>/dev/null || stat -c %s screenshots/dev/4.17-sample-diff.png)" -gt 30000 ]`.
  - Done: Screenshot exists; visual criteria above hold.
  - Refs: PLAN.md §3.3, §13.5.

- [ ] **4.18** Wire PHPicker entry point ("Clean photos…")
  - In `App/Views/RootView.swift`, add a primary "Clean photos…" button below "Try it on a sample photo". Tapping presents `PHPickerViewController` (wrapped in `UIViewControllerRepresentable`) with:
    - `selectionLimit: 0`
    - `preferredAssetRepresentationMode: .current` (CRITICAL — prevents HEIC→JPEG transcode; PLAN.md §3.2)
    - `filter: .any(of: [.images, .videos, .livePhotos])`
  - Selected items: load via `NSItemProvider.loadFileRepresentation`, hardlink into a fresh Workspace job, run `CleaningPipeline`, then present `UIActivityViewController` with the cleaned URLs.
  - Test: `xcodebuild ... -scheme CleanShare build ...`.
  - Done: Builds.
  - Refs: PLAN.md §3.2.

- [ ] **4.19** Sim verify PHPicker presentation
  - Boot sim with at least one synthetic photo (the sim seeds default media). From RootView: `ui_find_element "Clean photos"`, `ui_tap`. Wait 1 s. `screenshot` → `4.19-phpicker.png`. `ui_describe_all` — confirm "Photos" or "Select" text consistent with iOS PHPicker overlay.
  - Visual Check: The system PHPicker is overlaid on top of the app, showing the simulator's seeded photo library.
  - Note: If the simulator returns an empty PHPicker (no seeded media), use the iOS Photos app to import an image first via `xcrun simctl addmedia <UDID> tests/fixtures/dirty/iphone_sample.jpg`, then retry.
  - Test: `test -f screenshots/dev/4.19-phpicker.png`.
  - Done: Screenshot exists AND `ui_describe_all` mentions PHPicker UI elements.
  - Refs: PLAN.md §3.2.

- [ ] **4.20** Write Localizable.xcstrings (en-US baseline)
  - File: `App/Resources/Localizable.xcstrings`. Use Xcode's String Catalog format. Extract every user-facing string: button labels ("Clean photos…", "Try it on a sample photo", "Cancel", "Get started"), screen titles, alert messages, settings row labels.
  - Update call sites in `App/`, `Packages/CleanShareUI/Sources/` to use `String(localized:)` for these strings (so they resolve from the catalog).
  - Test: `test -f App/Resources/Localizable.xcstrings && plutil -lint App/Resources/Localizable.xcstrings && python3 -c "import json; d=json.load(open('App/Resources/Localizable.xcstrings')); assert d.get('sourceLanguage')=='en'; assert len(d.get('strings',{})) >= 10"`.
  - Done: Catalog parses AND has at least 10 strings.
  - Refs: PLAN.md §20 Week 4.

- [ ] **4.21** Sim record full happy-path video (PHPicker → clean → share sheet)
  - Boot sim. Seed it with `xcrun simctl addmedia <UDID> tests/fixtures/dirty/iphone_sample.jpg`. Build + install + launch.
  - `mcp__ios-simulator__record_video` → start recording to `screenshots/dev/4.21-full-flow.mov`.
  - Drive the UI:
    1. Tap "Clean photos…" (`ui_find_element` + `ui_tap`).
    2. In PHPicker, `ui_tap` the first image thumbnail.
    3. Tap "Add" (or whatever the picker's confirm button is).
    4. Wait 1 s for the cleaning progress UI.
    5. Wait for the `UIActivityViewController` share sheet.
    6. `ui_tap` "Cancel" (or "Done").
  - `mcp__ios-simulator__stop_recording`.
  - Also take three discrete screenshots at picker/progress/share-sheet moments: `4.21-step{1,2,3}.png`.
  - Visual Check (review the MOV): clean transition picker → progress → share-sheet; no crashes; no visible "??" placeholders; clean tear-down on dismiss.
  - Test: `test -f screenshots/dev/4.21-full-flow.mov && [ "$(stat -f %z screenshots/dev/4.21-full-flow.mov 2>/dev/null || stat -c %s screenshots/dev/4.21-full-flow.mov)" -gt 200000 ] && [ "$(ls screenshots/dev/4.21-step*.png 2>/dev/null | wc -l)" -eq 3 ]`.
  - Done: Video file exists (>200 KB), three step screenshots present.
  - Refs: PLAN.md §3.2, §20 Week 4.

- [ ] **4.22** Commit Phase 4
  - Stage: `git add App/ Packages/CleanShareUI/ scripts/generate-icons.sh`. Run `git status --short` first to confirm no stray gitignored files.
  - Commit message: `feat(ui): phase 4 — onboarding + settings + about + live-photo sheet + sample diff + PHPicker + l10n + icon`.
  - Test: `git log --oneline -1 | grep -q 'phase 4'`.
  - Done: Commit recorded.
  - Refs: PLAN.md §20 Week 4.

---

## Phase 5: Release infrastructure (workflows + landing + signing docs)

- [ ] **5.01** Write Gemfile + bundle install (Apple Silicon, no sudo)
  - Step 1 — ensure `bundler` is reachable WITHOUT sudo: if `command -v bundle` returns non-zero, run `gem install --user-install bundler`. Then make sure `~/.gem/ruby/<VERSION>/bin` is on PATH for the current shell (`export PATH="$HOME/.gem/ruby/$(ruby -e 'puts RUBY_VERSION.split(\".\").first(2).join(\".\") + \".0\"')/bin:$PATH"` — or rely on Homebrew Ruby being on PATH from CLAUDE.md pre-loop setup).
  - Step 2 — write `Gemfile`:
    ```ruby
    source "https://rubygems.org"
    gem "fastlane", "~> 2.224"
    ```
  - Step 3 — `bundle config set --local path 'vendor/bundle'` then `bundle install`. The `vendor/bundle` path is gitignored (verify via `.gitignore` from 1.03) so the agent never accidentally commits 100 MB of gems.
  - Step 4 — `Gemfile.lock` IS committed (locks fastlane version for reproducible builds).
  - Test: `test -f Gemfile && test -f Gemfile.lock && bundle exec fastlane --version 2>&1 | grep -q '^fastlane'`.
  - Done: `bundle exec fastlane --version` resolves without "command not found" and prints a fastlane version line.
  - Refs: PLAN.md §12; CLAUDE.md "Build environment (Apple Silicon)".

- [ ] **5.02** Write fastlane/Appfile
  - File:
    ```ruby
    app_identifier(["dev.cleanshare.app", "dev.cleanshare.app.ShareExtension"])
    apple_id(ENV["FASTLANE_APPLE_ID"] || "REPLACE_ME@cleanshare.dev")
    team_id(ENV["FASTLANE_TEAM_ID"] || "REPLACE_ME")
    ```
  - The `ENV[…]` fallbacks let CI inject real values without committing them.
  - Test: `test -f fastlane/Appfile && grep -q 'dev.cleanshare.app' fastlane/Appfile && grep -q 'FASTLANE_APPLE_ID' fastlane/Appfile`.
  - Done: File present with both bundle IDs and ENV fallbacks.
  - Refs: PLAN.md §12.1.

- [ ] **5.03** Write fastlane/Matchfile
  - File:
    ```ruby
    git_url(ENV["MATCH_GIT_URL"] || "")
    storage_mode("git")
    type("development")
    app_identifier(["dev.cleanshare.app", "dev.cleanshare.app.ShareExtension"])
    username(ENV["FASTLANE_APPLE_ID"]) if ENV["FASTLANE_APPLE_ID"]
    team_id(ENV["FASTLANE_TEAM_ID"]) if ENV["FASTLANE_TEAM_ID"]
    ```
  - Test: `test -f fastlane/Matchfile && grep -q 'storage_mode("git")' fastlane/Matchfile && grep -q MATCH_GIT_URL fastlane/Matchfile`.
  - Done: File present with the git storage mode and ENV-resolved git URL.
  - Refs: PLAN.md §12.1.

- [ ] **5.04** Write fastlane/Fastfile (4 lanes: test, certs, beta, release)
  - File: implements four lanes:
    - `lane :test` — runs `scan` against the CleanShare scheme on the latest iPhone simulator with no signing.
    - `lane :certs` — runs `match(type: "development", readonly: true)` AND `match(type: "appstore", readonly: true)` — readonly is critical so CI never accidentally creates new certs.
    - `lane :beta` — bumps the build number from `ENV["GITHUB_RUN_NUMBER"]`, runs `match(type: "appstore", readonly: true)`, runs `gym(scheme: "CleanShare", export_method: "app-store")`, then `pilot(skip_waiting_for_build_processing: true)` to upload.
    - `lane :release` — same as `:beta` but additionally calls `deliver(skip_screenshots: false, skip_metadata: false, submit_for_review: false, force: true)`.
  - Test: `test -f fastlane/Fastfile && for l in test certs beta release; do grep -q "lane :$l" fastlane/Fastfile || { echo "missing lane: $l"; exit 1; }; done && grep -q readonly fastlane/Fastfile && grep -q GITHUB_RUN_NUMBER fastlane/Fastfile`.
  - Done: All four lanes present; readonly Match; build number from GH Actions.
  - Refs: PLAN.md §12.1.

- [ ] **5.05** Write .github/workflows/release.yml
  - Triggers: `push.tags: ["v*.*.*"]` + `workflow_dispatch` with `lane` (default `release`) input. `environment: release` (manual approval gate).
  - Job runs on `macos-15`, `timeout-minutes: 60`. Steps: checkout v4 → select Xcode 16 → `brew install xcodegen` → `bundle install --path vendor/bundle` → decode `ASC_API_KEY_BASE64` secret to `~/.private_keys/AuthKey.p8` → `bundle exec fastlane "${{ inputs.lane || 'release' }}"`.
  - All secrets referenced via `${{ secrets.* }}`: `MATCH_PASSWORD`, `MATCH_GIT_URL`, `MATCH_GIT_BASIC_AUTHORIZATION`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_BASE64`, `FASTLANE_APPLE_ID`, `FASTLANE_TEAM_ID`.
  - Test: `test -f .github/workflows/release.yml && python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/release.yml')); assert 'release' in d.get('on', {}).get('workflow_dispatch', {}).get('inputs', {}).get('lane', {}).get('default','release') or 'release' in str(d)" && grep -q 'environment: release' .github/workflows/release.yml && for s in MATCH_PASSWORD MATCH_GIT_URL ASC_API_KEY_BASE64; do grep -q "$s" .github/workflows/release.yml || exit 1; done`.
  - Done: YAML parses; references all required secrets and the manual-approval environment.
  - Refs: PLAN.md §11.2, §11.7.

- [ ] **5.06** Write .github/workflows/nightly.yml
  - Triggers: `schedule: cron "0 6 * * *"` (06:00 UTC daily) + `workflow_dispatch`.
  - Job 1 (`fuzz`): macos-15, runs `cd Packages/CleanShareCore && CLEANSHARE_RUN_FUZZ=1 swift test --filter FuzzTests`.
  - Job 2 (`nightly-beta`): macos-15, depends on `fuzz`, uses `environment: release`, runs `bundle exec fastlane beta` with a nightly version bump (`fastlane action increment_build_number` from `GITHUB_RUN_NUMBER`).
  - Test: `test -f .github/workflows/nightly.yml && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/nightly.yml'))" && grep -q 'cron' .github/workflows/nightly.yml && grep -q 'CLEANSHARE_RUN_FUZZ' .github/workflows/nightly.yml`.
  - Done: YAML parses with cron + fuzz job + nightly TestFlight job.
  - Refs: PLAN.md §11.3.

- [ ] **5.07** Write .github/workflows/pages.yml
  - Triggers: `push.branches: [main]` (only when `marketing/landing/**` or `PRIVACY.md` changes — use `paths:` filter) + `workflow_dispatch`.
  - Uses GH Pages built-in actions: `actions/configure-pages@v5`, `actions/upload-pages-artifact@v3` with `path: marketing/landing/`, `actions/deploy-pages@v4`.
  - Permissions: `pages: write`, `id-token: write`.
  - Test: `test -f .github/workflows/pages.yml && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pages.yml'))" && grep -q deploy-pages .github/workflows/pages.yml`.
  - Done: YAML parses with the three deploy-pages actions.
  - Refs: PLAN.md §11.4, §14.3.

- [ ] **5.08** Write .github/workflows/codeql.yml
  - Triggers: `schedule: cron "0 12 * * 1"` (weekly Mondays) + `pull_request.branches: [main]` (path-filtered to Swift sources) + `workflow_dispatch`.
  - Uses `github/codeql-action/init@v3` with `languages: swift`, then `analyze@v3`.
  - Test: `test -f .github/workflows/codeql.yml && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/codeql.yml'))" && grep -q 'languages: swift' .github/workflows/codeql.yml`.
  - Done: YAML parses; targets Swift.
  - Refs: PLAN.md §11.5.

- [ ] **5.09** Write .github/workflows/stale.yml
  - Triggers: `schedule: cron "0 1 * * *"` daily.
  - Uses `actions/stale@v9` with: `days-before-stale: 60`, `days-before-close: 7`, `stale-issue-message`, `close-issue-message`, `exempt-issue-labels: 'pinned,roadmap,accepted'`, same for PRs.
  - Test: `test -f .github/workflows/stale.yml && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/stale.yml'))" && grep -q 'actions/stale@v9' .github/workflows/stale.yml && grep -q 'pinned' .github/workflows/stale.yml`.
  - Done: YAML parses with all required directives.
  - Refs: PLAN.md §11.6, §17.

- [ ] **5.10** Write docs/codesigning.md + docs/release-process.md
  - `docs/codesigning.md` covers: contributor flow (`Config/Local.xcconfig` with their own `DEVELOPMENT_TEAM_OVERRIDE` + `BUNDLE_PREFIX`; free Apple ID limits — 7-day re-signing, no App Groups so the URL-scheme handoff falls back to `UIDocumentPickerViewController` per PLAN.md §6.2). Maintainer flow (Fastlane Match against private signing repo, secrets list).
  - `docs/release-process.md` covers: pre-flight checks, `git tag -sa v0.X.Y`, `git push origin tag`, watch `release.yml`, App Store Connect manual submit, "Submit for Review" button, post-approval `Pending Developer Release` → release.
  - Test: `test -f docs/codesigning.md && test -f docs/release-process.md && grep -q 'Local.xcconfig' docs/codesigning.md && grep -q 'Match' docs/codesigning.md && grep -q 'TestFlight' docs/release-process.md`.
  - Done: Both docs exist with the required content pointers.
  - Refs: PLAN.md §12, §11.2.

- [ ] **5.11** Write scripts/bootstrap.sh (interactive contributor setup)
  - Behaviour:
    1. If `Config/Local.xcconfig` exists, prompt y/N before overwriting.
    2. Read `DEVELOPMENT_TEAM_OVERRIDE` from user input. Validate it's exactly 10 alphanumeric chars.
    3. Read `BUNDLE_PREFIX` from user input. Default to `dev.local`. Validate it's reverse-DNS shaped.
    4. Write `Config/Local.xcconfig`.
    5. Run `brew bundle` (if Brewfile exists).
    6. Run `bundle install --path vendor/bundle` (if Gemfile exists).
    7. Run `./scripts/generate-project.sh`.
    8. If `--open` flag passed, run `open CleanShare.xcodeproj`.
  - Inputs read via `read -rp "..."`. No `eval`. Quoted variable expansions throughout.
  - Test: `test -x scripts/bootstrap.sh && bash -n scripts/bootstrap.sh && grep -q DEVELOPMENT_TEAM_OVERRIDE scripts/bootstrap.sh && grep -q BUNDLE_PREFIX scripts/bootstrap.sh`.
  - Done: Script is executable, syntax-checks, prompts for both required vars.
  - Refs: PLAN.md §12.3.

- [ ] **5.12** Write marketing/landing/index.html + style.css
  - `marketing/landing/index.html` — single page, no build step. Hero section with the wordmark + tagline + App Store badge placeholder + TestFlight badge placeholder + GitHub octocat link. Three short explainer sections (What gets stripped / How it works / Privacy). Footer with links to `/privacy`, `/faq`, `/press`. Use Tailwind via CDN `<script src="https://cdn.tailwindcss.com">`.
  - `marketing/landing/style.css` — minimal custom CSS for the gradient hero background (teal→indigo) and any tweaks Tailwind can't express cleanly.
  - Test: `test -f marketing/landing/index.html && grep -q CleanShare marketing/landing/index.html && grep -q tailwind marketing/landing/index.html && test -f marketing/landing/style.css`.
  - Done: Both files exist; index references CleanShare and Tailwind CDN.
  - Refs: PLAN.md §14.3.

- [ ] **5.13** Write marketing/landing/privacy.html + press.html + faq.html + CNAME
  - `privacy.html` — render `PRIVACY.md` to HTML manually (no build step). Mirror every category answered "No" + the "CI tests for it on every commit" claim.
  - `press.html` — boilerplate press kit: short bio paragraph, 3 one-liners, "Download icons + screenshots" link to `https://github.com/<placeholder>/cleanshare/releases/latest/download/press-kit.zip`.
  - `faq.html` — short Q&A: "Why doesn't WhatsApp/IG show the cleaned metadata?" (because they re-encode), "Can I batch-clean?" (yes via PHPicker), "Does it work on iPad?" (yes).
  - `CNAME` — single line: `cleanshare.dev`.
  - Test: `for f in privacy.html press.html faq.html CNAME; do test -f "marketing/landing/$f" || exit 1; done && grep -q cleanshare.dev marketing/landing/CNAME`.
  - Done: All four files present.
  - Refs: PLAN.md §14.3.

- [ ] **5.14** Write docs/manual-steps.md (human-only checklist)
  - Captures every action the agent CANNOT do. Format: a markdown checklist with one-line "how" pointers. Required entries:
    - Apple Developer Program enrollment + Team ID recording.
    - Reserve App Store Connect bundle IDs: `dev.cleanshare.app` AND `dev.cleanshare.app.ShareExtension`.
    - Create private `cleanshare-signing` GitHub repo (Match storage).
    - Run `bundle exec fastlane match init` + `match appstore` LOCALLY on maintainer's Mac the first time (CI is readonly).
    - Configure GitHub `release` environment secrets: `MATCH_PASSWORD`, `MATCH_GIT_URL`, `MATCH_GIT_BASIC_AUTHORIZATION`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_BASE64`, `FASTLANE_APPLE_ID`, `FASTLANE_TEAM_ID`.
    - Buy `cleanshare.dev` domain.
    - DNS A records pointing GH Pages: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
    - Configure GH Pages custom domain in Settings → Pages.
    - Submit App Store Connect privacy questionnaire (every category answered "No").
    - Enable TestFlight public link.
    - Create `conduct@cleanshare.dev` mailbox (or update CODE_OF_CONDUCT.md with the real address).
    - Commission designer for the real app icon (CleanShare placeholder is just a CS wordmark on a gradient).
  - Test: `test -f docs/manual-steps.md && for s in 'cleanshare-signing' 'ASC_API_KEY_BASE64' 'cleanshare.dev' 'TestFlight' 'conduct@cleanshare.dev'; do grep -q "$s" docs/manual-steps.md || { echo "missing: $s"; exit 1; }; done`.
  - Done: All required entries present.
  - Refs: PLAN.md §11.7, §12, §13, §14.3, §17.

- [ ] **5.15** Commit Phase 5
  - Stage: `git add Gemfile Gemfile.lock fastlane/ .github/workflows/release.yml .github/workflows/nightly.yml .github/workflows/pages.yml .github/workflows/codeql.yml .github/workflows/stale.yml docs/ scripts/bootstrap.sh marketing/`.
  - Commit message: `feat(release): phase 5 — fastlane + 5 GH workflows + landing site + signing docs + manual-steps checklist`.
  - Test: `git log --oneline -1 | grep -q 'phase 5'`.
  - Done: Commit recorded.
  - Refs: PLAN.md §20 Week 5.

---

## Phase 6: App Store submission prep

- [ ] **6.01** Write scripts/screenshots.sh (the capture engine)
  - File: `scripts/screenshots.sh` (chmod +x). Adapt from marklens reference. Behaviour:
    - Resolves iPhone UDID via `xcrun simctl list devices available -j` looking for an iPhone whose name matches a 6.9"-class device. Preferred order: `iPhone 17 Pro Max`, `iPhone 16 Pro Max`, `iPhone 16 Plus`, `iPhone 15 Pro Max`. Use the first match. Allow override via `$IPHONE_UDID`.
    - Same lookup for iPad — preferred: `iPad Pro 13-inch (M5)`, `iPad Pro 13-inch (M4)`, `iPad Pro (12.9-inch) (6th generation)`. `$IPAD_UDID` override.
    - Boots each sim, installs the built `.app`, launches the app, drives the UI through the six iPhone shots / four iPad shots described below, saving to `screenshots/iPhone-6.9/01-hero.png` etc.
    - Shuts down both sims at the end (`xcrun simctl shutdown <UDID>`).
  - For each shot: `xcrun simctl io <UDID> screenshot --type=png <path>`. The native sim resolution at 6.9" is 1320×2868 (3× scale); at 13" it's 2064×2752. No scaling needed.
  - Test: `test -x scripts/screenshots.sh && bash -n scripts/screenshots.sh && grep -q 'simctl io' scripts/screenshots.sh && grep -q 'IPHONE_UDID' scripts/screenshots.sh`.
  - Done: Script is executable and parseable; references the override env vars.
  - Refs: PLAN.md §13.3.

- [ ] **6.02** Capture iPhone screenshot 01 — hero (RootView with "Clean photos…" CTA)
  - Run `scripts/screenshots.sh iphone-01-hero` (the script's first arg selects a single shot for incremental testing).
  - Expected output: `screenshots/iPhone-6.9/01-hero.png`, 1320×2868 PNG showing RootView with the wordmark + "Clean photos…" button prominently displayed.
  - Visual Check:
    1. PNG dimensions are exactly 1320×2868.
    2. "CleanShare" wordmark visible at the top.
    3. "Clean photos…" button is the most prominent CTA, centered.
    4. Status bar shows full battery, full signal (simctl status bar override should be applied — add `xcrun simctl status_bar <UDID> override --time 09:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3` to the script).
    5. No dev-only debug overlays.
  - Test: `test -f screenshots/iPhone-6.9/01-hero.png && python3 -c "from PIL import Image; im=Image.open('screenshots/iPhone-6.9/01-hero.png'); assert im.size==(1320,2868), im.size"` (install Pillow via `python3 -m pip install --user Pillow` if missing).
  - Done: Screenshot has correct dimensions; visual criteria above hold.
  - Refs: PLAN.md §13.3.

- [ ] **6.03** Capture iPhone screenshots 02–06 (all from real product UI — no marketing-only views)
  - 02 — sample-diff screen: launch app → tap "Try it on a sample photo" → wait for diff → capture. Real product flow. Output `screenshots/iPhone-6.9/02-diff.png` at 1320×2868.
  - 03 — share-sheet mid-flow: launch app → "Clean photos…" → pick seeded photo (`xcrun simctl addmedia booted tests/fixtures/dirty/iphone_sample.jpg` first) → wait for share sheet → capture during presentation. Output `03-share.png`.
  - 04 — video support callout: navigate Settings → About → scroll to the "Supported formats" section (added in 4.09) → capture. This is real product UI — the About → Supported formats section IS the App Store "video support" screenshot. Output `04-formats.png`.
  - 05 — Zero data collected: navigate Settings → About → scroll to the "Zero data collected" section (also added in 4.09) → capture. Output `05-privacy.png`.
  - 06 — Open source: navigate Settings → About → scroll to the "Open source (MIT)" section → capture. Output `06-source.png`.
  - All five from real shipping screens reachable through real user flows. NO marketing-only views, NO `#if DEBUG` entry points.
  - Test:
    ```bash
    for n in 02-diff 03-share 04-formats 05-privacy 06-source; do
      test -f "screenshots/iPhone-6.9/$n.png" || { echo "missing $n"; exit 1; }
      python3 -c "from PIL import Image; im=Image.open('screenshots/iPhone-6.9/$n.png'); assert im.size==(1320,2868), '$n size '+str(im.size)" || exit 1
    done
    # Negative assertion: source tree contains NO marketing-only views.
    ! find App Packages/CleanShareUI -type d -name 'Marketing' || { echo "Marketing/ dir exists — must use real product UI"; exit 1; }
    ! grep -rE '#if DEBUG' App/Views Packages/CleanShareUI/Sources/CleanShareUI/Settings Packages/CleanShareUI/Sources/CleanShareUI/About | grep -i 'screenshot\|marketing' || { echo "marketing #if DEBUG block found — remove"; exit 1; }
    ```
  - Done: All five screenshots at correct resolution; no marketing-only views in source; no marketing-tagged DEBUG blocks.
  - Refs: PLAN.md §13.3, §13.5.

- [ ] **6.04** Capture iPad screenshots 01–04
  - Run `scripts/screenshots.sh ipad`. Captures 4 screenshots at 2064×2752 mirroring the iPhone content: hero, diff, share-sheet, privacy card.
  - Output: `screenshots/iPad-13/01-hero.png` … `04-privacy.png`.
  - Visual Check: same as iPhone, but: layout makes use of the wider iPad canvas (e.g. RootView shows the "Try it" button + "Clean photos…" button side-by-side or in a larger card).
  - Test: `[ "$(ls screenshots/iPad-13/*.png 2>/dev/null | wc -l)" -eq 4 ] && for f in screenshots/iPad-13/*.png; do python3 -c "from PIL import Image; im=Image.open('$f'); assert im.size==(2064,2752), '$f '+str(im.size)" || exit 1; done`.
  - Done: Four iPad screenshots at the correct resolution.
  - Refs: PLAN.md §13.3.

- [ ] **6.05** Write fastlane/metadata/en-US/ — names + subtitle + description
  - `fastlane/metadata/en-US/name.txt` = `CleanShare` (single line, no newlines).
  - `fastlane/metadata/en-US/subtitle.txt` = `Strip metadata before sharing` (≤30 chars).
  - `fastlane/metadata/en-US/description.txt` — 3 paragraphs:
    1. The problem (EXIF leaks location, device, time).
    2. The product (shares to CleanShare → cleaned → shares onward).
    3. The promise (no accounts, no analytics, no network, open source under MIT).
  - Test: `test -f fastlane/metadata/en-US/name.txt && [ "$(wc -c < fastlane/metadata/en-US/subtitle.txt)" -le 31 ] && [ "$(wc -l < fastlane/metadata/en-US/description.txt)" -ge 5 ]`.
  - Done: All three files exist, subtitle within limit, description multi-paragraph.
  - Refs: PLAN.md §13.1.

- [ ] **6.06** Write fastlane/metadata/en-US/ — keywords + promo + URLs + release notes
  - `keywords.txt` (≤100 chars, CSV): `privacy,photo,metadata,exif,gps,share,strip,clean,open source,free`.
  - `promotional_text.txt` (≤170 chars): `Share photos and videos without leaking your location, camera model, or timestamps. One tap, no accounts, nothing leaves your device.`.
  - `support_url.txt` = `https://cleanshare.dev/support`.
  - `marketing_url.txt` = `https://cleanshare.dev`.
  - `privacy_url.txt` = `https://cleanshare.dev/privacy`.
  - `release_notes.txt` (v1.0.0 initial) = `Initial release. Open source under MIT.`.
  - Test: `for f in keywords promotional_text support_url marketing_url privacy_url release_notes; do test -f "fastlane/metadata/en-US/$f.txt" || exit 1; done && [ "$(wc -c < fastlane/metadata/en-US/keywords.txt)" -le 101 ] && [ "$(wc -c < fastlane/metadata/en-US/promotional_text.txt)" -le 171 ]`.
  - Done: All six files present and within their respective length limits.
  - Refs: PLAN.md §13.1.

- [ ] **6.07** Write fastlane/metadata/review_information/
  - `notes.txt` per PLAN.md §13.4:
    - "No account required. Demo username/password intentionally blank."
    - "Test the in-app pipeline: tap 'Try it on a sample photo'. The before/after diff shows EXIF/GPS removed."
    - "Test the share-extension pipeline: Photos → pick any photo → Share → CleanShare → Messages."
    - "Verify on-device only: Network Link Conditioner = 100% loss; app still works for all flows."
    - "Comparable approved apps: ViewExif, Metapho."
    - `Maintainer contact: <placeholder>@cleanshare.dev`.
  - `demo_user.txt`, `demo_password.txt` — empty (touch).
  - `first_name.txt`, `last_name.txt`, `email_address.txt`, `phone_number.txt` — placeholders the human will fill via docs/manual-steps.md before submission.
  - Test: `test -f fastlane/metadata/review_information/notes.txt && grep -q 'Network Link Conditioner' fastlane/metadata/review_information/notes.txt && grep -q 'sample photo' fastlane/metadata/review_information/notes.txt && grep -q ViewExif fastlane/metadata/review_information/notes.txt && test -f fastlane/metadata/review_information/demo_user.txt`.
  - Done: All required review-information files present with the required talking points.
  - Refs: PLAN.md §13.4.

- [ ] **6.08** Write docs/app-store-privacy.md
  - Documents that every category in the App Store Connect privacy questionnaire is answered "No" → resulting label "Data Not Collected".
  - Reference PLAN.md §9 + §18.
  - Note that the questionnaire is submitted via App Store Connect UI (already in `docs/manual-steps.md`).
  - Test: `test -f docs/app-store-privacy.md && grep -q 'Data Not Collected' docs/app-store-privacy.md && grep -q 'manual-steps' docs/app-store-privacy.md`.
  - Done: Doc exists with the required references.
  - Refs: PLAN.md §9, §13.2.

- [ ] **6.09** Commit Phase 6
  - Stage: `git add scripts/screenshots.sh screenshots/iPhone-6.9/ screenshots/iPad-13/ fastlane/metadata/ docs/app-store-privacy.md`.
  - Note: `screenshots/dev/` is gitignored — `screenshots/iPhone-6.9/` and `screenshots/iPad-13/` are NOT (these are App-Store-bound assets).
  - Commit message: `chore(release): phase 6 — App Store metadata + iPhone/iPad screenshots + review notes + privacy doc`.
  - Test: `git log --oneline -1 | grep -q 'phase 6'`.
  - Done: Commit recorded.
  - Refs: PLAN.md §20 Week 6.

---

## Phase 7: Quality (fuzz + perf + diagnostics + docs)

- [ ] **7.01** Implement FuzzTests (gated behind CLEANSHARE_RUN_FUZZ env var)
  - File: `Packages/CleanShareCore/Tests/CleanShareCoreTests/FuzzTests.swift`.
  - For each of the 5 image fixtures + the video fixture: generate 50 bit-flipped variants (mutate a random byte at a random offset, skipping the first 16 bytes of the file to avoid breaking magic numbers). Run the appropriate cleaner. Allowed outcomes per call: (a) succeeds with `receipt.leakedKeys.isEmpty == true`, OR (b) throws a `CleanerError`. Silent metadata retention is a failure.
  - In `setUp`, `try XCTSkipUnless(ProcessInfo.processInfo.environment["CLEANSHARE_RUN_FUZZ"] != nil, "Fuzz tests are nightly-only")`.
  - Test: `cd Packages/CleanShareCore && CLEANSHARE_RUN_FUZZ=1 swift test --filter FuzzTests` exits 0.
  - Done: Test passes with the gate set; running without the gate skips them quickly.
  - Refs: PLAN.md §8.4.

- [ ] **7.02** Implement NetworkSilenceTests (XCUITest)
  - File: `CleanShareUITests/NetworkSilenceTests.swift`.
  - In `setUp`, register a `URLProtocol` subclass `NetworkRecorder` (`URLProtocol.registerClass(NetworkRecorder.self)`). The recorder pushes every `canInit(with:)` URL into a static `recordedRequests: [URL]` array, then returns `false` so URLs fall through to the real loader.
  - Run the app via `XCUIApplication().launch()`. Drive: onboarding (Get started), tap "Try it on a sample photo", let it complete, dismiss. Tap "Clean photos…", pick a media item (use the simulator's seeded media), let cleaning + share-sheet finish, cancel the share sheet.
  - After each phase, assert `NetworkRecorder.recordedRequests.isEmpty`. Throw with the offending URLs if any.
  - Test: `xcodebuild -project CleanShare.xcodeproj -scheme CleanShare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:CleanShareUITests/NetworkSilenceTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO | xcbeautify --renderer terminal` exits 0.
  - Done: Test passes; zero recorded requests across all flows.
  - Refs: PLAN.md §8.5, §18.3.

- [ ] **7.03** Implement PerformanceTests
  - File: `Packages/CleanShareCore/Tests/CleanShareCoreTests/PerformanceTests.swift`. Three `measure {}` tests:
    1. `testPerfJPEG12MP_under500ms` — clean a 12-MP JPEG (generate via `scripts/make-perf-fixtures.sh` using ffmpeg: `ffmpeg -f lavfi -i nullsrc=s=4000x3000 -frames:v 1 -q:v 2 tests/fixtures/perf/jpeg_12mp.jpg` plus exiftool to add metadata). Baseline: < 500 ms (3× the PLAN.md §5.2 target of < 80 ms for CI overhead).
    2. `testPerfHEIC12MP_under400ms` — same dimensions but HEIC via `sips -s format heic`. Baseline: < 400 ms.
    3. `testPerf4KH264_under5s` — generate `tests/fixtures/perf/h264_4k_10s.mp4` (`ffmpeg -f lavfi -i testsrc=duration=10:size=3840x2160:rate=30 -c:v libx264 -pix_fmt yuv420p tests/fixtures/perf/h264_4k_10s.mp4`). Baseline: < 5 s.
  - Wire fixtures in `Package.swift` as resources.
  - Test: `bash scripts/make-perf-fixtures.sh && cd Packages/CleanShareCore && swift test --filter PerformanceTests`.
  - Done: All three measure blocks run AND meet their loose baselines on the dev machine.
  - Refs: PLAN.md §5.2, §8.

- [ ] **7.04** Implement MetricKitCollector
  - File: `Packages/CleanShareCore/Sources/CleanShareCore/Diagnostics/MetricKitCollector.swift` — `@MainActor public final class MetricKitCollector: NSObject, MXMetricManagerSubscriber`.
  - On `didReceive` callbacks, serialize each `MXMetricPayload` and `MXDiagnosticPayload` to JSON, prepend to a rolling list capped at 5, persist to `<AppGroup>/Diagnostics/reports.json`.
  - Two static API entry points: `MetricKitCollector.subscribe()` (idempotent — registers the subscriber once with `MXMetricManager.shared`) and `MetricKitCollector.unsubscribe()`. Only called when the user toggles the Diagnostics row in Settings.
  - Default state: NOT subscribed.
  - Test: `cd Packages/CleanShareCore && swift build`.
  - Done: Builds.
  - Refs: PLAN.md §18.2.

- [ ] **7.05** Implement DiagnosticsView + wire to SettingsView's diagnostics toggle
  - File: `Packages/CleanShareUI/Sources/CleanShareUI/Settings/DiagnosticsView.swift` — shows a list of the 5 most recent reports (date + brief summary) and an "Export Last 5 Crash Reports" button that opens a `UIActivityViewController` with the JSON file.
  - In `SettingsView` (from 4.06), tap the Diagnostics toggle → call `MetricKitCollector.subscribe()` (or `unsubscribe()`). Navigate from Settings → Diagnostics row → `DiagnosticsView`.
  - Test: `cd Packages/CleanShareUI && swift build`.
  - Done: Builds.
  - Refs: PLAN.md §18.2.

- [ ] **7.06** Write docs/architecture.md
  - Pull and re-render the architecture content from PLAN.md §2 (workspace + targets layout, Swift Package boundaries, App Group, URL scheme, why zero deps). Cross-link to docs/adr/*.md once they exist.
  - Test: `test -f docs/architecture.md && grep -q 'App Group' docs/architecture.md && grep -q 'CleanShareCore' docs/architecture.md`.
  - Done: Doc exists with the required cross-references.
  - Refs: PLAN.md §2.

- [ ] **7.07** Write docs/threat-model.md
  - Pull from PLAN.md §9 (privacy posture) + the threat enumeration implicit in §4 (per-format metadata risks). Document: in-scope threats (metadata leakage at share time), out-of-scope (the recipient app — WhatsApp re-encodes; document this), mitigations (fail-closed audit, CI privacy regression).
  - Test: `test -f docs/threat-model.md && grep -q 'fail-closed' docs/threat-model.md && grep -q 'recipient app' docs/threat-model.md`.
  - Done: Doc exists with required content.
  - Refs: PLAN.md §4, §9.

- [ ] **7.08** Write docs/metadata-reference.md
  - Pull PLAN.md §4.4 verbatim or close to it — the per-tag-family table (EXIF/GPS/IPTC/TIFF/MakerNote/XMP/PNG-ancillary/etc., what's stripped, what's preserved by default, what's user-toggleable).
  - Test: `test -f docs/metadata-reference.md && grep -q 'MakerApple' docs/metadata-reference.md && grep -q 'ICC' docs/metadata-reference.md`.
  - Done: Doc exists with the required tag references.
  - Refs: PLAN.md §4.4.

- [ ] **7.09** Write docs/adr/0001-record-architecture-decisions.md
  - The ADR-of-ADRs: explains we use the format (https://adr.github.io/madr/), how to propose a new ADR (open a PR adding a new numbered file), and the lifecycle (Proposed → Accepted → Superseded by NNNN).
  - Test: `test -f docs/adr/0001-record-architecture-decisions.md && grep -q 'Proposed' docs/adr/0001-record-architecture-decisions.md && grep -q 'Accepted' docs/adr/0001-record-architecture-decisions.md`.
  - Done: ADR-0001 exists.
  - Refs: PLAN.md §10.

- [ ] **7.10** Write docs/adr/0002-no-third-party-deps.md
  - Status: Accepted. Decision: zero third-party runtime dependencies. Rationale: privacy app auditability + supply-chain reduction. Consequences: no bundled HTTP client (we have no network); no bundled image decoders (ImageIO is enough); no bundled crash reporter (MetricKit is enough). Cite `scripts/check-no-trackers.sh` as the enforcement mechanism.
  - Test: `test -f docs/adr/0002-no-third-party-deps.md && grep -q 'Accepted' docs/adr/0002-no-third-party-deps.md && grep -q 'check-no-trackers' docs/adr/0002-no-third-party-deps.md`.
  - Done: ADR-0002 exists.
  - Refs: PLAN.md §15, §18.

- [ ] **7.11** Write docs/adr/0003-extension-handoff-to-host.md
  - Status: Accepted. Decision: share-extension hands off to the host app via `NSExtensionContext.open(_:completionHandler:)` + custom URL scheme `cleanshare://`. Rationale: extensions cannot present `UIActivityViewController`. Alternatives considered: file-export fallback only (worse UX), Universal Link (Phase 2 hardening). Document the fallback ladder (PLAN.md §6.2).
  - Test: `test -f docs/adr/0003-extension-handoff-to-host.md && grep -q 'UIActivityViewController' docs/adr/0003-extension-handoff-to-host.md && grep -q 'NSExtensionContext' docs/adr/0003-extension-handoff-to-host.md`.
  - Done: ADR-0003 exists.
  - Refs: PLAN.md §6.

- [ ] **7.12** Write docs/adr/0004-metrickit-only.md
  - Status: Accepted. Decision: opt-in MetricKit, on-device only, manual export. No Firebase/Sentry/Crashlytics. No auto-transmission.
  - Test: `test -f docs/adr/0004-metrickit-only.md && grep -q 'MetricKit' docs/adr/0004-metrickit-only.md && grep -q 'auto-transmission' docs/adr/0004-metrickit-only.md`.
  - Done: ADR-0004 exists.
  - Refs: PLAN.md §18.2.

- [ ] **7.13** Commit Phase 7
  - Stage: `git add Packages/ CleanShareUITests/ docs/architecture.md docs/threat-model.md docs/metadata-reference.md docs/adr/ scripts/make-perf-fixtures.sh tests/fixtures/perf/.gitkeep`.
  - (Performance fixtures themselves go in `tests/fixtures/perf/`; keep them out of git via `.gitignore` rule `tests/fixtures/perf/*.{jpg,heic,mp4}` and commit only `.gitkeep`.)
  - Commit message: `feat(quality): phase 7 — fuzz + network-silence + perf + MetricKit + docs + ADRs`.
  - Test: `git log --oneline -1 | grep -q 'phase 7'`.
  - Done: Commit recorded.
  - Refs: PLAN.md §20 Week 7.

---

## Phase 8: Final verification + RC tag

- [ ] **8.01** Local rehearsal: `make lint` is green
  - Run `make lint`. Resolve any SwiftFormat / SwiftLint complaints in-scope (do NOT add suppressions; either fix the code or update the config if the rule is genuinely wrong — and document the rationale in commit message).
  - Test: `make lint` exits 0.
  - Done: Lint passes.
  - Refs: PLAN.md §11.1.

- [ ] **8.02** Local rehearsal: `make test` is green
  - Run `make test`. This invokes both `swift test --package-path Packages/CleanShareCore` AND `xcodebuild test` for the app + extension test bundles.
  - Resolve any failures in-scope. Do NOT skip tests to make this pass.
  - Test: `make test` exits 0.
  - Done: All tests pass.
  - Refs: PLAN.md §8, §11.1.

- [ ] **8.03** Local rehearsal: `make verify-strip` is green
  - Run `make verify-strip`. This cleans every fixture and runs the external exiftool/ffprobe audit.
  - If any fixture fails the audit, that's a privacy bug — fix the cleaner; do not loosen the audit.
  - Test: `make verify-strip` exits 0.
  - Done: All fixtures verifiably stripped per external tools.
  - Refs: PLAN.md §8.3.

- [ ] **8.04** Sim verify sample-diff path on a fresh install
  - Wipe sim state: `xcrun simctl uninstall <UDID> dev.cleanshare.app`.
  - Build, install, launch. Complete onboarding via `ui_find_element` + `ui_tap`.
  - Tap "Try it on a sample photo". `screenshot` → `screenshots/dev/8.04-sample-clean.png`.
  - `ui_describe_all` — confirm BEFORE column contains "GPS" + "MakerApple"; AFTER column does NOT contain those substrings.
  - Visual Check (vision-capable inspection):
    1. Two side-by-side text columns clearly visible.
    2. GPS / MakerApple lines in BEFORE are visually flagged (red text).
    3. AFTER column is markedly shorter — most rows missing.
    4. No rendering glitches.
  - Test: `test -f screenshots/dev/8.04-sample-clean.png && [ "$(stat -f %z screenshots/dev/8.04-sample-clean.png 2>/dev/null || stat -c %s screenshots/dev/8.04-sample-clean.png)" -gt 30000 ]`.
  - Done: Screenshot exists; visual criteria above hold.
  - Refs: PLAN.md §3.3.

- [ ] **8.05** Sim record final end-to-end PHPicker → clean → share flow
  - Add a fresh media item: `xcrun simctl addmedia <UDID> tests/fixtures/dirty/iphone_sample.jpg`.
  - `mcp__ios-simulator__record_video` → start recording → `screenshots/dev/8.05-final-flow.mov`.
  - Drive: tap "Clean photos…" → pick the seeded photo → tap Add → wait for progress → wait for share sheet → tap "Cancel".
  - `mcp__ios-simulator__stop_recording`.
  - Also capture three discrete screenshots at picker/progress/share-sheet: `8.05-step{1,2,3}.png`.
  - Visual Check (review the MOV): smooth flow from app → picker → progress → share sheet; no crash dialogs; no broken layouts at the picker → progress transition; share sheet shows multiple destinations (Messages, AirDrop, Save Image, etc.).
  - Test: `test -f screenshots/dev/8.05-final-flow.mov && [ "$(stat -f %z screenshots/dev/8.05-final-flow.mov 2>/dev/null || stat -c %s screenshots/dev/8.05-final-flow.mov)" -gt 500000 ] && [ "$(ls screenshots/dev/8.05-step*.png 2>/dev/null | wc -l)" -eq 3 ]`.
  - Done: Video >500 KB; three step screenshots present; visual criteria satisfied.
  - Refs: PLAN.md §3.2.

- [ ] **8.06** Remove all placeholder source files
  - Delete the files that existed only to satisfy XcodeGen / Swift Package Manager during early-phase scaffolding, now superseded by real code:
    - `Packages/CleanShareCore/Sources/CleanShareCore/CleanShareCore.swift` (the `public enum CleanShareCore { static let version = "0.0.0" }` namespace) — deleted; no consumer should reference it (`grep -r 'CleanShareCore\.version'` in App/, ShareExtension/, Packages/ returns no matches).
    - `Packages/CleanShareCore/Tests/CleanShareCoreTests/CleanShareCoreTests.swift` (the `testVersionNotEmpty` placeholder test) — deleted; real tests in `ImageIOCleanerTests`, `AVPassthroughCleanerTests`, etc. now cover the package.
    - `Packages/CleanShareUI/Sources/CleanShareUI/Placeholder.swift` — deleted.
    - `Packages/CleanShareUI/Tests/CleanShareUITests/PlaceholderTests.swift` — deleted.
    - `CleanShareTests/Placeholder.swift`, `CleanShareUITests/Placeholder.swift`, `ShareExtensionTests/Placeholder.swift` — each deleted (real tests in the respective bundles supersede them).
  - After deletion, `swift build` for both packages MUST still succeed (because no real code referenced these placeholders).
  - Test: `! test -f Packages/CleanShareCore/Sources/CleanShareCore/CleanShareCore.swift && ! test -f Packages/CleanShareUI/Sources/CleanShareUI/Placeholder.swift && [ "$(find CleanShareTests CleanShareUITests ShareExtensionTests -name 'Placeholder.swift' 2>/dev/null | wc -l)" -eq 0 ] && [ "$(find Packages -name 'Placeholder*.swift' 2>/dev/null | wc -l)" -eq 0 ] && cd Packages/CleanShareCore && swift build && cd ../CleanShareUI && swift build`.
  - Done: All placeholder files removed AND both packages still build.
  - Refs: PLAN.md §10; CLAUDE.md "No-mocks principle".

- [ ] **8.07** Remove all debug-only UI affordances
  - Grep the source tree for `#if DEBUG` blocks that wrap user-facing UI (buttons, menu items, navigation links, sheet triggers, marketing views). Allowed `#if DEBUG`: pure logging (`print(...)`), test-helper accessors not connected to UI. Forbidden: anything that adds a tappable element to a SwiftUI view body, or that conditionally registers a SwiftUI scene/window.
  - Specifically remove if still present:
    - Any "(debug)" or "(test)" labelled button in `SettingsView`.
    - Any `App/Views/Marketing/` directory (must not exist — Phase 6 captures from real product UI per CLAUDE.md "No-mocks principle").
    - Any `#if DEBUG` block in `SettingsView`, `AboutView`, `OnboardingView`, `RootView`, `SampleDiffView`, `LivePhotoConsentSheet`.
  - Allowed exception: `Sample-DirtyLivePhoto.{heic,mov}` resources bundled in 4.12 fallback — these are PRODUCTION resources for the "Try it on a Live Photo (sample)" feature, NOT debug-gated.
  - Test:
    ```bash
    # No Marketing/ dirs
    ! find App Packages/CleanShareUI -type d -name 'Marketing' 2>/dev/null | grep -q .
    # No "(debug)" labels in UI source
    ! grep -rn '"(debug)"\|"(test)"\|debug-only' App/Views Packages/CleanShareUI/Sources/ 2>/dev/null
    # No #if DEBUG wrapping View body content (heuristic: #if DEBUG within 5 lines of `var body`)
    ! python3 - <<'PY'
    import re, pathlib, sys
    bad = []
    for f in list(pathlib.Path("Packages/CleanShareUI/Sources").rglob("*.swift")) + list(pathlib.Path("App").rglob("*.swift")):
        text = f.read_text()
        for m in re.finditer(r"#if\s+DEBUG", text):
            # look at next ~10 lines for SwiftUI-ish view elements
            tail = text[m.end():m.end()+800]
            if re.search(r"\b(Button|NavigationLink|Toggle|Section|VStack|HStack|ZStack|List|Form)\b", tail):
                bad.append(f"{f}:{text[:m.start()].count(chr(10))+1}")
    if bad:
        print("FAIL — DEBUG-gated UI in:")
        for b in bad: print(" ", b)
        sys.exit(1)
    PY
    ```
  - Done: No `Marketing/` directory exists, no `(debug)`/`(test)` labels in UI source, no `#if DEBUG` block within 800 chars of a SwiftUI view-construction keyword.
  - Refs: CLAUDE.md "No-mocks principle".

- [ ] **8.08** Final no-mocks sweep
  - Confirm there is no remaining `TODO:` / `FIXME:` / `XXX:` comment in production targets (App/, ShareExtension/, Packages/*/Sources/). Such comments in tests are allowed.
  - Confirm there is no `fatalError("not implemented")` / `fatalError("TODO")` in production targets.
  - Confirm there is no `_ = ...` stub assignment in production targets that exists solely to silence a warning about an unused mock.
  - Test:
    ```bash
    BAD=$(grep -rnE '(TODO|FIXME|XXX):|fatalError\("(not implemented|TODO|stub)' App/ ShareExtension/ Packages/*/Sources/ 2>/dev/null || true)
    if [ -n "$BAD" ]; then echo "$BAD"; exit 1; fi
    ```
  - Done: Grep returns no output (exit 0).
  - Refs: CLAUDE.md "No-mocks principle".

- [ ] **8.09** Re-run full quality gate after scaffolding removal
  - Now that placeholders and debug UI are gone, run the entire local CI chain once more to confirm nothing regressed:
    ```bash
    make lint && make test && make verify-strip && bash scripts/check-no-trackers.sh
    ```
  - Also re-build the app for sim and confirm it launches: install fresh, launch, `mcp__ios-simulator__screenshot` → `screenshots/dev/8.09-post-cleanup.png`. Use vision to confirm the app still shows the right home screen.
  - Visual Check (LOOK at the screenshot):
    1. App launches without crashing.
    2. RootView (or onboarding if prefs were wiped) renders correctly.
    3. No "(debug)" labels visible anywhere.
    4. No regressions vs the visual state captured in 8.04 / 8.05.
  - Test: `make lint && make test && make verify-strip && bash scripts/check-no-trackers.sh && test -f screenshots/dev/8.09-post-cleanup.png`.
  - Done: All four gates pass + post-cleanup screenshot exists + visual criteria hold.
  - Refs: PLAN.md §8, §11.1.

- [ ] **8.10** Update CHANGELOG.md for v0.1.0
  - Move the `## [Unreleased]` section content under a new `## [0.1.0] - <today YYYY-MM-DD>` heading (substitute today's date from `date +%F`).
  - Leave a fresh empty `## [Unreleased]` heading at the top.
  - Test: `grep -q '## \[0.1.0\]' CHANGELOG.md && head -20 CHANGELOG.md | grep -q '## \[Unreleased\]'`.
  - Done: Both the new release heading AND a fresh Unreleased heading exist.
  - Refs: PLAN.md §16.

- [ ] **8.11** Final commit + tag v0.1.0
  - Stage: `git add CHANGELOG.md` plus any deletions from 8.06 / 8.07 (run `git status --short` first to see what `git rm` already staged automatically).
  - Commit: `chore(release): v0.1.0 — feature-complete release candidate (scaffolding cleared, no mocks).`.
  - Tag: `git tag -a v0.1.0 -m "v0.1.0 — feature-complete RC. App Store submission pending docs/manual-steps.md."`.
  - Do NOT push. Do NOT push the tag. Human releases.
  - This is the final automated task. After this, the loop terminates.
  - Test: `git tag --list | grep -q '^v0.1.0$' && git log --oneline -1 | grep -q 'v0.1.0' && ! git ls-files | xargs grep -lE 'public enum CleanShareCore' 2>/dev/null | grep -q CleanShareCore.swift && ! find . -path ./node_modules -prune -o -name 'Placeholder*.swift' -print 2>/dev/null | grep -q Placeholder`.
  - Done: Tag exists on HEAD commit; placeholder files are absent from the working tree AND from git history HEAD; commit message references the release candidate.
  - Refs: PLAN.md §16, §20 Week 8; CLAUDE.md "No-mocks principle".
