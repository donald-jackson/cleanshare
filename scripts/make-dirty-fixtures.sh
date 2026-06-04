#!/usr/bin/env bash
# Generates synthetic "dirty" image fixtures (metadata-laden) for the test suite.
# Pixels are synthesized in-house from solid colors — no source-photo provenance.
# Metadata is injected with exiftool. See tests/fixtures/README.md (CC0).
set -euo pipefail
cd "$(dirname "$0")/.."

DIRTY="tests/fixtures/dirty"
mkdir -p "$DIRTY"

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found on PATH" >&2; exit 1; }; }
need exiftool
need sips
need ffmpeg
need swift

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A solid-color source PNG at a given size: solid_png <w> <h> <color> <out>
solid_png() {
    ffmpeg -nostdin -loglevel error -y -f lavfi -i "color=c=$3:s=${1}x${2}:d=1" -frames:v 1 "$4"
}

# 1. iphone_sample.jpg — 200x200 JPEG with GPS + Apple make/model + MakerNote
solid_png 200 200 teal "$tmp/iphone.png"
sips -s format jpeg "$tmp/iphone.png" --out "$DIRTY/iphone_sample.jpg" >/dev/null
exiftool -overwrite_original \
    -MakerNotes:CameraSerialNumber=ABC123 \
    -EXIF:GPSLatitudeRef=N -EXIF:GPSLatitude='51.5074 N' \
    -EXIF:GPSLongitudeRef=W -EXIF:GPSLongitude='0.1278 W' \
    -EXIF:Make=Apple -EXIF:Model='iPhone 15 Pro' \
    "$DIRTY/iphone_sample.jpg" >/dev/null

# 2. pixel_sample.jpg — 200x200 JPEG with EXIF + XMP Creator
solid_png 200 200 navy "$tmp/pixel.png"
sips -s format jpeg "$tmp/pixel.png" --out "$DIRTY/pixel_sample.jpg" >/dev/null
exiftool -overwrite_original \
    -EXIF:Make=Google -EXIF:Model='Pixel 8' \
    -XMP:Creator=TestUser \
    "$DIRTY/pixel_sample.jpg" >/dev/null

# 3. transparent.png — 64x64 transparent PNG with tEXt comment
ffmpeg -nostdin -loglevel error -y -f lavfi \
    -i "color=c=black@0.0:s=64x64:d=1" -frames:v 1 -pix_fmt rgba "$DIRTY/transparent.png"
exiftool -overwrite_original -PNG:Comment='leak this' "$DIRTY/transparent.png" >/dev/null

# 4. animated.gif — 2-frame GIF with XMP packet
solid_png 64 64 red "$tmp/g0.png"
solid_png 64 64 blue "$tmp/g1.png"
ffmpeg -nostdin -loglevel error -y -framerate 2 -i "$tmp/g%d.png" "$DIRTY/animated.gif"
exiftool -overwrite_original -XMP:Creator=GIFTester "$DIRTY/animated.gif" >/dev/null

# 5. lightroom.jpg — 200x200 JPEG with heavy XMP block + custom subjects
solid_png 200 200 purple "$tmp/lr.png"
sips -s format jpeg "$tmp/lr.png" --out "$DIRTY/lightroom.jpg" >/dev/null
exiftool -overwrite_original \
    -XMP:Creator='Lightroom Tester' \
    -XMP:Subject='cat,dog' \
    -XMP-dc:Description='heavy XMP block synthesized for metadata-strip testing' \
    -XMP-lr:HierarchicalSubject='animals|cat' \
    -XMP:Rating=5 \
    "$DIRTY/lightroom.jpg" >/dev/null

# 6. h264_short.mp4 — 2s H.264 clip with QuickTime location + make/model atoms
ffmpeg -nostdin -loglevel error -y -f lavfi -i 'testsrc=duration=2:size=320x240:rate=30' \
    -c:v libx264 -pix_fmt yuv420p \
    -metadata location='+51.5074-000.1278/' \
    -metadata 'com.apple.quicktime.make=Apple' \
    -metadata 'com.apple.quicktime.model=iPhone 15 Pro' \
    "$DIRTY/h264_short.mp4"

# 7. livephoto.{heic,mov} — a synthetic Live Photo pair sharing the content
#    identifier ABC-123-DEADBEEF. exiftool/ffmpeg cannot synthesize the Apple
#    content-identifier keys that ImageIO/AVFoundation actually read — the still's
#    MakerApple dictionary tag 17 and the video's mdta
#    com.apple.quicktime.content.identifier — so we inject them with the same
#    ImageIO / AVFoundation APIs the engine itself uses. See PLAN.md §4.5.
LP_ID="ABC-123-DEADBEEF"

solid_png 200 200 orange "$tmp/lp.png"
sips -s format heic "$tmp/lp.png" --out "$tmp/lp_base.heic" >/dev/null

cat > "$tmp/inject_still.swift" <<'SWIFT'
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import Foundation
let args = CommandLine.arguments
let inURL = URL(fileURLWithPath: args[1]), outURL = URL(fileURLWithPath: args[2]), id = args[3]
guard let src = CGImageSourceCreateWithURL(inURL as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("read still") }
var props = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]) ?? [:]
props[kCGImagePropertyMakerAppleDictionary] = ["17": id]
guard let dest = CGImageDestinationCreateWithURL(
    outURL as CFURL, UTType.heic.identifier as CFString, 1, nil) else { fatalError("dest") }
CGImageDestinationAddImage(dest, img, props as CFDictionary)
guard CGImageDestinationFinalize(dest) else { fatalError("finalize still") }
SWIFT
swift "$tmp/inject_still.swift" "$tmp/lp_base.heic" "$DIRTY/livephoto.heic" "$LP_ID"

ffmpeg -nostdin -loglevel error -y -f lavfi -i 'testsrc=duration=1:size=200x200:rate=30' \
    -c:v libx264 -pix_fmt yuv420p "$tmp/lp_base.mov"

cat > "$tmp/inject_video.swift" <<'SWIFT'
import AVFoundation
import CoreMedia
import Foundation
let args = CommandLine.arguments
let inURL = URL(fileURLWithPath: args[1]), outURL = URL(fileURLWithPath: args[2]), id = args[3]
try? FileManager.default.removeItem(at: outURL)
guard let export = AVAssetExportSession(
    asset: AVURLAsset(url: inURL), presetName: AVAssetExportPresetPassthrough) else { fatalError("export") }
let item = AVMutableMetadataItem()
item.identifier = .quickTimeMetadataContentIdentifier
item.dataType = kCMMetadataBaseDataType_UTF8 as String
item.value = id as NSString
export.outputURL = outURL
export.outputFileType = .mov
export.metadata = [item]
let sem = DispatchSemaphore(value: 0)
export.exportAsynchronously { sem.signal() }
sem.wait()
guard export.status == .completed else { fatalError("export status \(export.status.rawValue)") }
SWIFT
swift "$tmp/inject_video.swift" "$tmp/lp_base.mov" "$DIRTY/livephoto.mov" "$LP_ID"

echo "Generated dirty fixtures in $DIRTY:"
ls -1 "$DIRTY"
