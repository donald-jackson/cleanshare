import ImageIO

// Builds the property dictionaries handed to `CGImageDestinationAddImage` /
// `CGImageDestinationSetProperties`. Every PII-bearing dictionary is explicitly
// deleted via `kCFNull` (omission would mean "inherit from source"); only the
// keys the user opted into are added back. See PLAN.md §4.2 and §4.4.

/// Per-frame properties: nulls every known metadata dictionary, then adds back
/// orientation and/or capture date if the preferences allow it.
func sanitizedFrameProperties(
    from src: CGImageSource,
    frameIndex: Int,
    prefs: CleaningPreferences,
    kind: MediaKind
) -> [CFString: Any] {
    var out: [CFString: Any] = [:]

    // The PNG and HEIC/HEIF encoders reject a kCFNull deletion of the Exif/TIFF
    // containers and fail CGImageDestinationFinalize. Because each frame is
    // re-added from a freshly decoded CGImage (which carries no metadata), those
    // dictionaries cannot leak source PII regardless of the kCFNull. See PLAN.md §4.2.
    let allowsExifTIFFNull = kind != .png && kind != .heic && kind != .heif

    // Explicit delete via kCFNull — NOT omission.
    if allowsExifTIFFNull { out[kCGImagePropertyExifDictionary] = kCFNull }
    out[kCGImagePropertyExifAuxDictionary] = kCFNull
    out[kCGImagePropertyGPSDictionary] = kCFNull
    out[kCGImagePropertyIPTCDictionary] = kCFNull
    if allowsExifTIFFNull { out[kCGImagePropertyTIFFDictionary] = kCFNull }
    out[kCGImagePropertyJFIFDictionary] = kCFNull
    out[kCGImagePropertyMakerAppleDictionary] = kCFNull
    out[kCGImagePropertyMakerNikonDictionary] = kCFNull
    out[kCGImagePropertyMakerCanonDictionary] = kCFNull
    out[kCGImagePropertyMakerFujiDictionary] = kCFNull
    out[kCGImagePropertyMakerOlympusDictionary] = kCFNull
    out[kCGImagePropertyMakerPentaxDictionary] = kCFNull
    out[kCGImagePropertyMakerMinoltaDictionary] = kCFNull
    out[kCGImagePropertyPNGDictionary] = kCFNull
    out[kCGImagePropertyHEICSDictionary] = kCFNull
    out["{XMP}" as CFString] = kCFNull
    out["{Photoshop}" as CFString] = kCFNull
    out["{IPTCXMP}" as CFString] = kCFNull

    let srcProps = CGImageSourceCopyPropertiesAtIndex(src, frameIndex, nil) as? [CFString: Any]

    // Add-back allowlist. Each prefs.keepX flag re-attaches the exact field
    // the user opted into — never a whole sensitive dictionary unless the
    // entire dictionary is in scope (GPS).
    if prefs.keepOrientation,
       let orientation = srcProps?[kCGImagePropertyOrientation] {
        out[kCGImagePropertyOrientation] = orientation // root-level — NOT inside TIFF/EXIF subdicts
    }
    if prefs.keepGPS,
       let gps = srcProps?[kCGImagePropertyGPSDictionary] as? [CFString: Any],
       !gps.isEmpty {
        // GPS dictionary as a whole: coordinates, altitude, fix timestamp,
        // direction, speed. The Settings toggle warns the user this exposes
        // location, so re-attach the source's GPS verbatim.
        out[kCGImagePropertyGPSDictionary] = gps
    }
    if prefs.keepCaptureDate,
       let exif = srcProps?[kCGImagePropertyExifDictionary] as? [CFString: Any],
       let date = exif[kCGImagePropertyExifDateTimeOriginal] {
        out[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: date]
    }
    if prefs.keepCameraMakeModel,
       let tiff = srcProps?[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
        // Just Make and Model — not Software, Artist, Copyright, DateTime
        // (those are separate concerns covered by other prefs / always stripped).
        var subset: [CFString: Any] = [:]
        if let make = tiff[kCGImagePropertyTIFFMake] { subset[kCGImagePropertyTIFFMake] = make }
        if let model = tiff[kCGImagePropertyTIFFModel] { subset[kCGImagePropertyTIFFModel] = model }
        if !subset.isEmpty {
            out[kCGImagePropertyTIFFDictionary] = subset
        }
    }
    // `prefs.keepCustomXMP` is currently a no-op: round-tripping the XMP
    // packet through `CGImageSourceCopyPropertiesAtIndex` /
    // `CGImageDestinationAddImage` doesn't actually rewrite the packet on
    // most encoders (ImageIO expects `CGImageMetadata` for that, via
    // `CGImageDestinationAddImageAndMetadata`). Not exposed in Settings
    // either, so silently ignoring it doesn't surprise any user yet —
    // tracked for a future change.
    // ICC profile travels with CGImage.colorSpace — no key needed.

    return out
}

/// Container-level properties: preserves only structural keys (e.g. GIF loop
/// count) so animated formats keep playing correctly. Returns nil when there is
/// nothing structural to carry over.
func sanitizedContainerProperties(
    from src: CGImageSource,
    prefs _: CleaningPreferences
) -> [CFString: Any]? {
    guard let containerProps = CGImageSourceCopyProperties(src, nil) as? [CFString: Any] else {
        return nil
    }

    var out: [CFString: Any] = [:]

    if let gif = containerProps[kCGImagePropertyGIFDictionary] as? [CFString: Any],
       let loopCount = gif[kCGImagePropertyGIFLoopCount] {
        out[kCGImagePropertyGIFDictionary] = [kCGImagePropertyGIFLoopCount: loopCount]
    }

    return out.isEmpty ? nil : out
}
