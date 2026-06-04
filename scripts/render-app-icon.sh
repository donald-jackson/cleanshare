#!/usr/bin/env bash
# Render marketing/icon/AppIcon.svg to:
#   - App/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png (Xcode AppIcon)
#   - marketing/press-kit/icons/AppIcon-{2048,512,256,128}.png (press kit)
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "ERROR: rsvg-convert not on PATH. Run: brew install librsvg" >&2
    exit 1
fi

SRC="marketing/icon/AppIcon.svg"
APPICON_DIR="App/Resources/Assets.xcassets/AppIcon.appiconset"
PRESS_DIR="marketing/press-kit/icons"
mkdir -p "$APPICON_DIR" "$PRESS_DIR"

rsvg-convert -w 1024 -h 1024 -o "$APPICON_DIR/Icon-1024.png" "$SRC"
for size in 2048 512 256 128; do
    rsvg-convert -w "$size" -h "$size" -o "$PRESS_DIR/AppIcon-${size}.png" "$SRC"
done

# Verify the main 1024 PNG dimensions
python3 - "$APPICON_DIR/Icon-1024.png" <<PY
from PIL import Image
import sys
im = Image.open(sys.argv[1])
assert im.size == (1024, 1024), f"Expected 1024x1024, got {im.size}"
print(f"OK {sys.argv[1]} {im.size}")
PY
