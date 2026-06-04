import ImageIO

/// Builds the property dictionaries handed to `CGImageDestinationAddImage` /
/// `CGImageDestinationSetProperties`. Every PII-bearing dictionary is explicitly
/// deleted via `kCFNull` (omission would mean "inherit from source"); only the
/// keys the user opted into are added back. See PLAN.md §4.2 and §4.4.

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

    // Add-back allowlist.
    if prefs.keepOrientation,
       let orientation = srcProps?[kCGImagePropertyOrientation] {
        out[kCGImagePropertyOrientation] = orientation  // root-level — NOT inside TIFF/EXIF subdicts
    }
    if prefs.keepCaptureDate,
       let exif = srcProps?[kCGImagePropertyExifDictionary] as? [CFString: Any],
       let date = exif[kCGImagePropertyExifDateTimeOriginal] {
        out[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: date]
    }
    // ICC profile travels with CGImage.colorSpace — no key needed.

    return out
}

/// Container-level properties: preserves only structural keys (e.g. GIF loop
/// count) so animated formats keep playing correctly. Returns nil when there is
/// nothing structural to carry over.
func sanitizedContainerProperties(
    from src: CGImageSource,
    prefs: CleaningPreferences
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
