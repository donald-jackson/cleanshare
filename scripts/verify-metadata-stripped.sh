#!/usr/bin/env bash
# verify-metadata-stripped.sh — external-tool cross-check that a file carries no
# identifying metadata. PLAN.md §8.3 (Layer 3). Complements the in-house
# MetadataAuditor: uses exiftool/ffprobe (not ImageIO) so an ImageIO bug that
# hides a tag from CGImageSource cannot slip past us.
#
# Usage: verify-metadata-stripped.sh <file> [<file> ...]
#   Images (.jpg/.jpeg/.heic/.heif/.png/.gif/.tiff/.webp):
#     exiftool -a -G1 -j → flag any GPS/IPTC/XMP/Photoshop/MakerNotes group key,
#     or any EXIF-family tag outside the structural allowlist below.
#   Videos (.mp4/.mov):
#     ffprobe -show_format -show_streams → flag any non-empty format/stream tags.
#
# Prints "OK <file>" per clean file. On any leak, prints "LEAK <file> <key>"
# and exits 1.
#
# NOTE (carried from task 2.11): ImageIO unavoidably regenerates structural
# {Exif}(ColorSpace, PixelXDimension, PixelYDimension) and {JFIF} on cleaned
# JPEG/PNG output, and orientation is kept by default. Those tags are PII-free,
# so the EXIF check is an allowlist of structural tags rather than "no EXIF dict
# at all" — otherwise every cleaned image would false-positive. For the same
# reason XMP-x:XMPToolkit (a constant writer-version string, e.g. "XMP Core
# 6.0.0") is exempted: ImageIO injects an XMP packet wrapper on PNG output and
# the toolkit identifier carries no PII. Every other XMP tag is still a leak.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found on PATH" >&2; exit 2; }; }
need jq

# EXIF-family tags that ImageIO regenerates and that carry no PII. Anything in an
# EXIF subgroup (IFD0/IFD1/ExifIFD/SubIFD/InteropIFD/PrintIM) NOT in this list is
# treated as a leak.
EXIF_STRUCTURAL_ALLOW='[
  "ColorSpace","ExifImageWidth","ExifImageHeight","ExifVersion",
  "ComponentsConfiguration","FlashpixVersion","ImageWidth","ImageHeight",
  "ImageLength","Orientation","ResolutionUnit","XResolution","YResolution",
  "BitsPerSample","Compression","PhotometricInterpretation","SamplesPerPixel",
  "PlanarConfiguration","YCbCrSubSampling","YCbCrPositioning","RowsPerStrip",
  "StripOffsets","StripByteCounts"
]'

# Structural PNG chunk tags (IHDR/pHYs/gAMA/cHRM/sRGB/PLTE/tRNS/bKGD/sBIT).
# Any PNG-group tag outside this list (tEXt/zTXt/iTXt comments, software, author,
# timestamps, etc.) is treated as a leak.
PNG_STRUCTURAL_ALLOW='[
  "ImageWidth","ImageHeight","BitDepth","ColorType","Compression","Filter",
  "Interlace","SRGBRendering","Gamma","Palette","Transparency","BackgroundColor",
  "SignificantBits","PixelsPerUnitX","PixelsPerUnitY","PixelUnits",
  "WhitePointX","WhitePointY","RedX","RedY","GreenX","GreenY","BlueX","BlueY"
]'

verify_image() {
    local file="$1"
    need exiftool
    local json leaks
    json="$(exiftool -a -G1 -j "$file")"
    leaks="$(printf '%s' "$json" | jq -r \
        --argjson allow "$EXIF_STRUCTURAL_ALLOW" \
        --argjson pngAllow "$PNG_STRUCTURAL_ALLOW" '
        (.[0] // {})
        | to_entries
        | map(select(.key | contains(":")))
        | map({
            group: (.key | split(":")[0]),
            tag:   (.key | split(":")[1:] | join(":"))
          })
        | map(select(
            . as $e
            | (($e.group | test("^XMP")) and ($e.tag != "XMPToolkit"))
            or (["GPS","IPTC","IPTC2","Photoshop","MakerNotes"] | index($e.group) != null)
            or ($e.group | test("MakerNotes"))
            or (
                (["IFD0","IFD1","ExifIFD","SubIFD","InteropIFD","PrintIM"] | index($e.group) != null)
                and (($allow | index($e.tag)) == null)
            )
            or (
                ($e.group | test("^PNG"))
                and (($pngAllow | index($e.tag)) == null)
            )
          ))
        | map(.group + ":" + .tag)
        | .[]
    ')"
    if [ -n "$leaks" ]; then
        while IFS= read -r key; do
            [ -n "$key" ] && echo "LEAK $file $key"
        done <<< "$leaks"
        return 1
    fi
    echo "OK $file"
}

verify_video() {
    local file="$1"
    need ffprobe
    local json leaks
    json="$(ffprobe -v error -show_format -show_streams -of json "$file")"
    leaks="$(printf '%s' "$json" | jq -r '
        [ (.format.tags // {}) | to_entries[] | "format." + .key ]
        + [ (.streams // [])[] | (.tags // {}) | to_entries[] | "stream." + .key ]
        | .[]
    ')"
    if [ -n "$leaks" ]; then
        while IFS= read -r key; do
            [ -n "$key" ] && echo "LEAK $file $key"
        done <<< "$leaks"
        return 1
    fi
    echo "OK $file"
}

if [ "$#" -eq 0 ]; then
    echo "usage: $(basename "$0") <file> [<file> ...]" >&2
    exit 2
fi

status=0
for file in "$@"; do
    if [ ! -f "$file" ]; then
        echo "error: no such file: $file" >&2
        status=1
        continue
    fi
    ext="$(printf '%s' "${file##*.}" | tr '[:upper:]' '[:lower:]')"
    case "$ext" in
        jpg|jpeg|heic|heif|png|gif|tiff|tif|webp)
            verify_image "$file" || status=1
            ;;
        mp4|mov)
            verify_video "$file" || status=1
            ;;
        *)
            echo "error: unsupported extension: .$ext ($file)" >&2
            status=1
            ;;
    esac
done

exit "$status"
