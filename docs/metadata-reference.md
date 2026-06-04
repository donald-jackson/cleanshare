# Metadata Reference

This is the authoritative, per-tag-family reference for what CleanShare strips,
what it preserves, and what the user can toggle. It re-renders
[PLAN.md](../PLAN.md) §4.4 and is the document to consult when you want to know
"will sharing through CleanShare remove tag X?".

The engine implementation lives in `Packages/CleanShareCore/Sources/Engine/`
(`ImageIOCleaner`, `PropertySanitizer`, `AVPassthroughCleaner`,
`LivePhotoCleaner`); the guarantees below are mechanically verified by
`MetadataAuditor` (fail-closed, PLAN.md §8.1) and the golden-fixture +
exiftool cross-check CI gates (§8.2–§8.3).

## Default behavior at a glance

CleanShare's stance is **strip by default**. The only things preserved out of
the box are the structural and rendering-correctness fields a recipient needs to
see the image the way the sender saw it: color (ICC), orientation, and the
intrinsic structural descriptors (dimensions, duration, codec format).

## Per-tag-family table

| Tag family | Stripped by default | Notes |
|---|---|---|
| EXIF (GPS, DateTime, camera Make/Model, lens, ISO, exposure) | Yes | DateTime and Make/Model preservable via prefs |
| EXIF Aux (Apple-specific aux dict) | Yes | |
| GPS IFD | Yes | Hard no by default; user must explicitly enable in Settings, behind an "are you sure?" confirmation |
| IPTC | Yes | |
| TIFF (when present in JPEG/HEIC as IFD0) | Yes | Strips Software, ImageDescription, Artist, Copyright, etc. |
| MakerNote (Apple, Canon, Nikon, Sony, Fuji, Olympus, Pentax, Minolta) | Yes | MakerApple is the biggest privacy threat — it carries Live Photo pairing UUIDs |
| XMP packet | Yes | |
| Photoshop / IPTC-XMP | Yes | |
| PNG ancillary chunks (tEXt, iTXt, zTXt, eXIf, tIME) | Yes | |
| GIF Application Extension blocks (XMP, etc.) | Yes | Loop count + GCE preserved (structural) |
| WebP EXIF/XMP chunks | Yes | ICCP kept (color) |
| QuickTime mdta/udta atoms | Yes | |
| Per-track timed-metadata tracks | Yes | Dropped by not adding a writer input |
| ICC color profile | **No** (preserved by default) | Color correctness; toggleable off in Settings |
| Orientation | **No** (preserved by default) | Rendering correctness |
| Pixel/frame dimensions, duration, codec format description | **No** (structural) | |

## User-toggleable preferences

These map to `CleaningPreferences` (PLAN.md §4.6). All default to the
privacy-preserving choice except the two rendering/color fields.

| Preference | Default | Effect when enabled |
|---|---|---|
| `keepOrientation` | `true` | Preserve the orientation tag so images render upright |
| `keepICCProfile` | `true` | Preserve the embedded ICC color profile for color correctness |
| `keepCaptureDate` | `false` | Preserve EXIF DateTime / capture timestamp |
| `keepGPS` | `false` (hard no) | Preserve the GPS IFD — requires explicit opt-in with confirmation |
| `keepCameraMakeModel` | `false` | Preserve EXIF camera Make/Model |
| `keepCustomXMP` | `false` | Preserve the XMP packet |
| `preserveVideoCreationDate` | `false` | Preserve the QuickTime creation date for video |
| `livePhotoMode` | `.prompt` | Controls Live Photo pairing handling (see below) |

## MakerNote and the Live Photo pairing UUID

`MakerApple` is called out separately because it is the highest-value privacy
leak in an Apple photo: it carries the Live Photo pairing UUID (key `"17"`),
which correlates the still to its paired video and back to other assets in the
user's library. CleanShare strips the entire MakerNote by default.

For Live Photos specifically, the pairing UUID also lives on the video side as a
QuickTime `mdta` metadata item (`com.apple.quicktime.content.identifier`). The
`livePhotoMode` preference (PLAN.md §4.5) governs whether the pair is downgraded
to a still, kept with the original pairing UUID, or re-paired with a freshly
generated UUID.

## What CleanShare deliberately preserves

- **ICC color profile** — without it, colors shift on the recipient's display.
  Toggleable off for users who want maximum strip and accept the color risk.
- **Orientation** — without it, images may appear rotated.
- **Structural descriptors** — pixel/frame dimensions, duration, and the codec
  format description are intrinsic to decoding the file, not identifying
  metadata, and are always preserved.

See the [Threat Model](./threat-model.md) for how these guarantees are enforced
and what falls outside CleanShare's scope.
