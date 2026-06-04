#!/usr/bin/env bash
# screenshots.sh — App Store screenshot capture engine. PLAN.md §13.3.
#
# Captures the 6 iPhone (6.9", 1320×2868) and 4 iPad (13", 2064×2752) App Store
# screenshots from the REAL product UI — no marketing-only views (no-mocks
# principle, CLAUDE.md). It handles the deterministic plumbing: resolving a
# simulator UDID, booting it, installing the built .app, pinning a clean
# 09:41 status bar, launching the app, capturing PNGs via `simctl io`, and
# shutting the sims down at the end.
#
# Interactive navigation between shots (tapping "Try it on a sample photo",
# picking a library photo, opening Settings → About, etc.) is performed against
# the booted sim before each non-hero capture. When run by a human, drive those
# taps in the Simulator window during the pause the script prints; when run by
# the build agent, the agent drives them via the ios-simulator tooling and then
# invokes the matching single-shot subcommand to grab the frame.
#
# Usage:
#   scripts/screenshots.sh                 # capture full iPhone + iPad sets
#   scripts/screenshots.sh iphone          # all six iPhone shots
#   scripts/screenshots.sh ipad            # all four iPad shots
#   scripts/screenshots.sh iphone-01-hero  # a single named iPhone shot
#   scripts/screenshots.sh ipad-01-hero    # a single named iPad shot
#
# Overrides:
#   IPHONE_UDID=<udid>   skip iPhone device resolution, use this sim
#   IPAD_UDID=<udid>     skip iPad device resolution, use this sim
#   PAUSE=<seconds>      time given to set up each non-hero shot (default 6)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PAUSE="${PAUSE:-6}"

# Preferred 6.9"-class iPhones and 13" iPads, most-preferred first. The first
# name that exists as an available simulator wins.
IPHONE_DEVICES=(
    "iPhone 17 Pro Max"
    "iPhone 16 Pro Max"
    "iPhone 16 Plus"
    "iPhone 15 Pro Max"
)
IPAD_DEVICES=(
    "iPad Pro 13-inch (M5)"
    "iPad Pro 13-inch (M4)"
    "iPad Pro (12.9-inch) (6th generation)"
)

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found on PATH" >&2; exit 2; }; }
need xcrun
need jq
need python3

# Host-app bundle id, honouring a contributor BUNDLE_PREFIX override.
bundle_id() {
    local prefix="dev.cleanshare"
    if [ -f Config/Local.xcconfig ]; then
        local override
        override="$(grep -E '^BUNDLE_PREFIX' Config/Local.xcconfig | awk -F= '{print $2}' | tr -d ' ')"
        [ -n "$override" ] && prefix="$override"
    fi
    echo "${prefix}.app"
}
BUNDLE_ID="$(bundle_id)"

# Absolute path to the built CleanShare.app for the simulator. Picks the most
# recently built one if DerivedData holds several.
find_app() {
    local app
    app="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
        -name 'CleanShare.app' -path '*/Debug-iphonesimulator/*' -type d 2>/dev/null \
        | head -1)"
    if [ -z "$app" ]; then
        echo "error: CleanShare.app not found in DerivedData — build the app first:" >&2
        echo "  xcodebuild -project CleanShare.xcodeproj -scheme CleanShare \\" >&2
        echo "    -destination 'generic/platform=iOS Simulator' -configuration Debug build \\" >&2
        echo "    CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO" >&2
        exit 3
    fi
    echo "$app"
}

# Resolve a UDID for the first available device whose name matches one of the
# preferred names. $1 = "iphone" | "ipad".
resolve_udid() {
    local kind="$1"
    local -a names
    if [ "$kind" = "iphone" ]; then
        names=("${IPHONE_DEVICES[@]}")
    else
        names=("${IPAD_DEVICES[@]}")
    fi
    local devices_json
    devices_json="$(xcrun simctl list devices available -j)"
    local name udid
    for name in "${names[@]}"; do
        udid="$(printf '%s' "$devices_json" | jq -r --arg n "$name" '
            [ .devices[][] | select(.name == $n) ] | (.[0].udid // empty)')"
        if [ -n "$udid" ]; then
            echo "$udid"
            return 0
        fi
    done
    echo "error: no available $kind simulator among: ${names[*]}" >&2
    echo "  list with: xcrun simctl list devices available" >&2
    exit 4
}

ensure_booted() {
    local udid="$1"
    local state
    state="$(xcrun simctl list devices -j | jq -r --arg u "$udid" \
        '[ .devices[][] | select(.udid == $u) ] | (.[0].state // "Unknown")')"
    if [ "$state" != "Booted" ]; then
        xcrun simctl boot "$udid"
    fi
    xcrun simctl bootstatus "$udid" -b
}

pin_status_bar() {
    local udid="$1"
    xcrun simctl status_bar "$udid" override \
        --time "09:41" \
        --batteryState charged --batteryLevel 100 \
        --cellularBars 4 --wifiBars 3
}

install_app() {
    local udid="$1" app
    app="$(find_app)"
    xcrun simctl install "$udid" "$app"
}

launch_app() {
    local udid="$1"
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
}

# Capture a single screenshot. $1 = udid, $2 = output path (dirs created).
capture() {
    local udid="$1" path="$2"
    mkdir -p "$(dirname "$path")"
    xcrun simctl io "$udid" screenshot --type=png "$path"
    echo "captured $path"
}

# Give time (human) / a hook point (agent) to navigate to the right screen.
stage() {
    local what="$1"
    echo ">> stage: $what — navigate now (${PAUSE}s)…"
    sleep "$PAUSE"
}

# Prepare a device: boot, install, pin status bar.
prepare() {
    local udid="$1"
    ensure_booted "$udid"
    install_app "$udid"
    pin_status_bar "$udid"
}

# ---- iPhone shots -----------------------------------------------------------
IPHONE_DIR="screenshots/iPhone-6.9"

shot_iphone_01_hero() {
    local udid="$1"
    launch_app "$udid"
    sleep 3
    capture "$udid" "$IPHONE_DIR/01-hero.png"
}

shot_iphone_02_diff() {
    local udid="$1"
    launch_app "$udid"
    stage "tap 'Try it on a sample photo' → wait for the before/after diff"
    capture "$udid" "$IPHONE_DIR/02-diff.png"
}

shot_iphone_03_share() {
    local udid="$1"
    xcrun simctl addmedia "$udid" tests/fixtures/dirty/iphone_sample.jpg 2>/dev/null || true
    launch_app "$udid"
    stage "tap 'Clean photos…' → pick the seeded photo → wait for the share sheet"
    capture "$udid" "$IPHONE_DIR/03-share.png"
}

shot_iphone_04_formats() {
    local udid="$1"
    launch_app "$udid"
    stage "Settings → About → scroll to 'Supported formats'"
    capture "$udid" "$IPHONE_DIR/04-formats.png"
}

shot_iphone_05_privacy() {
    local udid="$1"
    launch_app "$udid"
    stage "Settings → About → scroll to 'Zero data collected'"
    capture "$udid" "$IPHONE_DIR/05-privacy.png"
}

shot_iphone_06_source() {
    local udid="$1"
    launch_app "$udid"
    stage "Settings → About → scroll to 'Open source (MIT)'"
    capture "$udid" "$IPHONE_DIR/06-source.png"
}

# ---- iPad shots -------------------------------------------------------------
IPAD_DIR="screenshots/iPad-13"

shot_ipad_01_hero() {
    local udid="$1"
    launch_app "$udid"
    sleep 3
    capture "$udid" "$IPAD_DIR/01-hero.png"
}

shot_ipad_02_diff() {
    local udid="$1"
    launch_app "$udid"
    stage "tap 'Try it on a sample photo' → wait for the before/after diff"
    capture "$udid" "$IPAD_DIR/02-diff.png"
}

shot_ipad_03_share() {
    local udid="$1"
    xcrun simctl addmedia "$udid" tests/fixtures/dirty/iphone_sample.jpg 2>/dev/null || true
    launch_app "$udid"
    stage "tap 'Clean photos…' → pick the seeded photo → wait for the share sheet"
    capture "$udid" "$IPAD_DIR/03-share.png"
}

shot_ipad_04_privacy() {
    local udid="$1"
    launch_app "$udid"
    stage "Settings → About → scroll to 'Zero data collected'"
    capture "$udid" "$IPAD_DIR/04-privacy.png"
}

# ---- orchestration ----------------------------------------------------------
iphone_all() {
    local udid="$1"
    prepare "$udid"
    shot_iphone_01_hero "$udid"
    shot_iphone_02_diff "$udid"
    shot_iphone_03_share "$udid"
    shot_iphone_04_formats "$udid"
    shot_iphone_05_privacy "$udid"
    shot_iphone_06_source "$udid"
}

ipad_all() {
    local udid="$1"
    prepare "$udid"
    shot_ipad_01_hero "$udid"
    shot_ipad_02_diff "$udid"
    shot_ipad_03_share "$udid"
    shot_ipad_04_privacy "$udid"
}

shutdown_sim() {
    local udid="$1"
    xcrun simctl shutdown "$udid" 2>/dev/null || true
}

usage() {
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
}

main() {
    local target="${1:-all}"

    case "$target" in
        -h|--help|help)
            usage
            exit 0
            ;;
        all)
            local iphone ipad
            iphone="${IPHONE_UDID:-$(resolve_udid iphone)}"
            ipad="${IPAD_UDID:-$(resolve_udid ipad)}"
            iphone_all "$iphone"
            ipad_all "$ipad"
            shutdown_sim "$iphone"
            shutdown_sim "$ipad"
            ;;
        iphone)
            local iphone
            iphone="${IPHONE_UDID:-$(resolve_udid iphone)}"
            iphone_all "$iphone"
            shutdown_sim "$iphone"
            ;;
        ipad)
            local ipad
            ipad="${IPAD_UDID:-$(resolve_udid ipad)}"
            ipad_all "$ipad"
            shutdown_sim "$ipad"
            ;;
        iphone-*)
            local iphone fn
            iphone="${IPHONE_UDID:-$(resolve_udid iphone)}"
            fn="shot_${target//-/_}"
            if ! declare -F "$fn" >/dev/null; then
                echo "error: unknown shot '$target'" >&2
                exit 5
            fi
            prepare "$iphone"
            "$fn" "$iphone"
            shutdown_sim "$iphone"
            ;;
        ipad-*)
            local ipad fn
            ipad="${IPAD_UDID:-$(resolve_udid ipad)}"
            fn="shot_${target//-/_}"
            if ! declare -F "$fn" >/dev/null; then
                echo "error: unknown shot '$target'" >&2
                exit 5
            fi
            prepare "$ipad"
            "$fn" "$ipad"
            shutdown_sim "$ipad"
            ;;
        *)
            echo "error: unknown target '$target'" >&2
            usage
            exit 5
            ;;
    esac
}

main "$@"
