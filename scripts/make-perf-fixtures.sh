#!/usr/bin/env bash
# Generates synthetic large-media fixtures for PerformanceTests. Pixels are
# synthesized in-house (nullsrc / testsrc) — no source-photo provenance.
# Metadata is injected with exiftool. Outputs land in tests/fixtures/perf/ and
# are mirrored into the test target's PerfFixtures resource dir so
# `Bundle.module` can load them. See PLAN.md §5.2, §8.
set -euo pipefail
cd "$(dirname "$0")/.."

PERF="tests/fixtures/perf"
RES="Packages/CleanShareCore/Tests/CleanShareCoreTests/PerfFixtures"
mkdir -p "$PERF" "$RES"

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found on PATH" >&2; exit 1; }; }
need ffmpeg
need exiftool
need sips

# 1. jpeg_12mp.jpg — 4000x3000 (12 MP) JPEG with GPS + make/model + MakerNote.
ffmpeg -nostdin -loglevel error -y -f lavfi -i nullsrc=s=4000x3000 \
    -frames:v 1 -q:v 2 "$PERF/jpeg_12mp.jpg"
exiftool -overwrite_original \
    -MakerNotes:CameraSerialNumber=PERF123 \
    -EXIF:GPSLatitudeRef=N -EXIF:GPSLatitude='51.5074 N' \
    -EXIF:GPSLongitudeRef=W -EXIF:GPSLongitude='0.1278 W' \
    -EXIF:Make=Apple -EXIF:Model='iPhone 15 Pro' \
    "$PERF/jpeg_12mp.jpg" >/dev/null

# 2. heic_12mp.heic — same 12-MP frame transcoded to HEIC, then dirtied.
sips -s format heic "$PERF/jpeg_12mp.jpg" --out "$PERF/heic_12mp.heic" >/dev/null
exiftool -overwrite_original \
    -EXIF:Make=Apple -EXIF:Model='iPhone 15 Pro' \
    -XMP:Creator=PerfTester \
    "$PERF/heic_12mp.heic" >/dev/null

# 3. h264_4k_10s.mp4 — 10s 4K H.264 clip with QuickTime location + make/model.
ffmpeg -nostdin -loglevel error -y \
    -f lavfi -i 'testsrc=duration=10:size=3840x2160:rate=30' \
    -c:v libx264 -pix_fmt yuv420p \
    -metadata location='+51.5074-000.1278/' \
    -metadata 'com.apple.quicktime.make=Apple' \
    -metadata 'com.apple.quicktime.model=iPhone 15 Pro' \
    "$PERF/h264_4k_10s.mp4"

# Mirror into the test target's resource dir.
cp "$PERF/jpeg_12mp.jpg" "$PERF/heic_12mp.heic" "$PERF/h264_4k_10s.mp4" "$RES/"

echo "Generated perf fixtures:"
ls -lh "$PERF"
