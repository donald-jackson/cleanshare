#!/usr/bin/env bash
# check-no-trackers.sh — assert no forbidden analytics / crash-reporting / ad-attribution
# SDK symbols appear in CleanShare source OR in the built .app binary.
# PLAN.md §8.6, §18.3. This is the mechanical enforcement of the "zero third-party
# tracking, Data Not Collected" promise.
#
# Sources scanned: App/, ShareExtension/, Packages/CleanShareCore/Sources/,
#   Packages/CleanShareUI/Sources/ (each only if it exists).
# Binary scanned: the most recent Debug-iphonesimulator CleanShare.app, if built.
#
# Matching is case-insensitive. Lines containing the marker "// FORBIDDEN:" are
# exempt from the SOURCE scan so docs/comments may legitimately name the SDKs
# (e.g. the marketing claim or this very list).
#
# Exits non-zero on any match; prints "OK" and exits 0 on a clean tree.
set -euo pipefail

# Forbidden SDK identifiers. Kept as one alternation so a single grep pass covers
# all of them. Anchored on the distinctive vendor token; case-insensitive.
FORBIDDEN='Firebase|Mixpanel|Amplitude|Sentry|Bugsnag|Crashlytics|FBSDK|FacebookCore|AppsFlyer|Branch\.io'

# Forbidden NETWORKING symbols. CleanShare makes zero network calls; this is the
# mechanical enforcement of that promise (the "verified by CI" in the marketing).
# Case-sensitive (these are exact API names). `URL(` is intentionally NOT here —
# the app builds file: and handoff URLs constantly; it's network *I/O* that's
# banned, not the URL type. Lines marked "// FORBIDDEN:" are exempt.
NETWORK='URLSession|URLRequest|NWConnection|NWListener|NWPathMonitor|NWBrowser|import[[:space:]]+Network|CFSocket|CFStream|CFHTTP|getaddrinfo|gethostbyname|\.dataTask|\.downloadTask|\.uploadTask'

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0

# --- Source scan ---------------------------------------------------------------
src_dirs=()
for d in App ShareExtension Packages/CleanShareCore/Sources Packages/CleanShareUI/Sources; do
    [ -d "$d" ] && src_dirs+=("$d")
done

if [ "${#src_dirs[@]}" -gt 0 ]; then
    # grep -r case-insensitive; drop lines marked as intentional doc references.
    matches="$(grep -rniE "$FORBIDDEN" "${src_dirs[@]}" 2>/dev/null | grep -v '// FORBIDDEN:' || true)"
    if [ -n "$matches" ]; then
        echo "FORBIDDEN tracker symbol(s) found in source:" >&2
        printf '%s\n' "$matches" >&2
        status=1
    fi

    # Network-symbol scan (case-sensitive, exact API names). Only Swift sources.
    net_matches="$(grep -rnE "$NETWORK" "${src_dirs[@]}" --include='*.swift' 2>/dev/null | grep -v '// FORBIDDEN:' || true)"
    if [ -n "$net_matches" ]; then
        echo "FORBIDDEN networking symbol(s) found in source (CleanShare must make no network calls):" >&2
        printf '%s\n' "$net_matches" >&2
        status=1
    fi
fi

# --- Binary scan ---------------------------------------------------------------
app="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
    -name 'CleanShare.app' -type d -path '*/Debug-iphonesimulator/*' 2>/dev/null | head -1 || true)"

if [ -n "$app" ] && command -v strings >/dev/null 2>&1; then
    bin="$app/CleanShare"
    if [ -f "$bin" ]; then
        bin_matches="$(strings "$bin" 2>/dev/null | grep -niE "$FORBIDDEN" || true)"
        if [ -n "$bin_matches" ]; then
            echo "FORBIDDEN tracker symbol(s) found in binary ($bin):" >&2
            printf '%s\n' "$bin_matches" >&2
            status=1
        fi
    fi
fi

if [ "$status" -eq 0 ]; then
    echo "OK — no forbidden tracker symbols in source or binary"
fi

exit "$status"
