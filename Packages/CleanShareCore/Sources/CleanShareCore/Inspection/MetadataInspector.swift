import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

/// Read-only counterpart to `MetadataAuditor`: decodes the identifying metadata
/// a file currently carries into a human-readable list, so the user can see
/// what a recipient would receive if they shared the file *without* CleanShare.
///
/// This is deliberately not the inverse of the cleaning pipeline: the auditor
/// asks "is anything still here that shouldn't be?" and answers in terms of
/// raw key names. The inspector asks "what will leak if I share this?" and
/// answers in terms a non-expert user can read ("GPS coordinates 37.77°,
/// -122.42°", not `{GPS}`).
public enum MetadataInspector {
    /// Inspect a single media file. Returns a structured list of identifying
    /// fields; the list is empty when the file carries nothing identifying.
    public static func inspect(url: URL, kind: MediaKind) async throws -> MetadataInspection {
        switch kind {
        case .jpeg, .heic, .heif, .png, .gif, .webp, .tiff, .dng, .livePhoto:
            try self.inspectImage(url: url)
        case .mp4, .mov:
            try await self.inspectVideo(url: url)
        }
    }

    // MARK: - Image

    private static func inspectImage(url: URL) throws -> MetadataInspection {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw CleanerError.unreadable
        }
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            return MetadataInspection(fields: [])
        }

        var fields: [MetadataField] = []

        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            fields.append(contentsOf: self.extractGPS(gps))
        }
        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            fields.append(contentsOf: self.extractTIFF(tiff))
        }
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            fields.append(contentsOf: self.extractExif(exif))
        }
        if let exifAux = props[kCGImagePropertyExifAuxDictionary] as? [CFString: Any], !exifAux.isEmpty {
            fields.append(.init(
                category: .device,
                label: "Apple Exif extras",
                value: "\(exifAux.count) Apple-specific Exif fields",
                severity: .high
            ))
        }
        if let iptc = props[kCGImagePropertyIPTCDictionary] as? [CFString: Any], !iptc.isEmpty {
            fields.append(self.summarise(iptc, label: "IPTC", category: .authoring, severity: .medium))
        }
        if let xmp = props["{XMP}" as CFString] as? String, !xmp.isEmpty {
            let snippet = xmp.replacingOccurrences(of: "\n", with: " ").prefix(140)
            fields.append(.init(
                category: .authoring,
                label: "XMP packet",
                value: snippet + (xmp.count > 140 ? "…" : ""),
                severity: .medium
            ))
        }
        if let photoshop = props["{Photoshop}" as CFString] as? [CFString: Any], !photoshop.isEmpty {
            fields.append(self.summarise(photoshop, label: "Photoshop", category: .authoring, severity: .medium))
        }
        if let png = props[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
            fields.append(contentsOf: self.extractPNG(png))
        }

        fields.append(contentsOf: self.extractMakerNotes(props))

        return MetadataInspection(fields: fields)
    }
}

// MARK: - Image field extraction

extension MetadataInspector {
    /// PNG `tEXt`/`iTXt` chunks carry authorship and timestamps that are
    /// invisible to the Exif/TIFF/GPS extractors above — so without this a PNG
    /// exported by an editor would be reported "already clean" when it still
    /// names its author. The cleaner + auditor already strip `{PNG}`; this makes
    /// the pre-clean inspector's coverage match.
    private static func extractPNG(_ png: [CFString: Any]) -> [MetadataField] {
        var out: [MetadataField] = []
        func text(_ key: CFString) -> String? {
            (png[key] as? String).flatMap { $0.isEmpty ? nil : $0 }
        }
        if let author = text(kCGImagePropertyPNGAuthor) {
            out.append(.init(category: .authoring, label: "Author (PNG)", value: author, severity: .high))
        }
        if let copyright = text(kCGImagePropertyPNGCopyright) {
            out.append(.init(category: .authoring, label: "Copyright (PNG)", value: copyright, severity: .high))
        }
        if let title = text(kCGImagePropertyPNGTitle) {
            out.append(.init(category: .authoring, label: "Title (PNG)", value: title, severity: .medium))
        }
        if let description = text(kCGImagePropertyPNGDescription) {
            out.append(.init(category: .authoring, label: "Description (PNG)", value: description, severity: .medium))
        }
        if let software = text(kCGImagePropertyPNGSoftware) {
            out.append(.init(category: .authoring, label: "Software (PNG)", value: software, severity: .medium))
        }
        if let created = text(kCGImagePropertyPNGCreationTime) {
            out.append(.init(category: .capture, label: "Creation time (PNG)", value: created, severity: .medium))
        }
        return out
    }

    private static func extractGPS(_ gps: [CFString: Any]) -> [MetadataField] {
        var out: [MetadataField] = []

        if let lat = (gps[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue,
           let lon = (gps[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue {
            let latRef = (gps[kCGImagePropertyGPSLatitudeRef] as? String) ?? "N"
            let lonRef = (gps[kCGImagePropertyGPSLongitudeRef] as? String) ?? "E"
            let signedLat = latRef == "S" ? -lat : lat
            let signedLon = lonRef == "W" ? -lon : lon
            out.append(.init(
                category: .location,
                label: "GPS coordinates",
                value: String(format: "%.6f°, %.6f°", signedLat, signedLon),
                severity: .high
            ))
        }
        if let alt = (gps[kCGImagePropertyGPSAltitude] as? NSNumber)?.doubleValue {
            let belowSeaLevel = (gps[kCGImagePropertyGPSAltitudeRef] as? NSNumber)?.intValue == 1
            out.append(.init(
                category: .location,
                label: "Altitude",
                value: String(format: "%@%.1f m", belowSeaLevel ? "-" : "", alt),
                severity: .high
            ))
        }
        if let date = gps[kCGImagePropertyGPSDateStamp] as? String {
            let time = gps[kCGImagePropertyGPSTimeStamp] as? String
            out.append(.init(
                category: .location,
                label: "Position fix timestamp",
                value: [date, time].compactMap(\.self).joined(separator: " "),
                severity: .high
            ))
        }
        if let direction = (gps[kCGImagePropertyGPSImgDirection] as? NSNumber)?.doubleValue {
            out.append(.init(
                category: .location,
                label: "Direction camera was facing",
                value: String(format: "%.0f°", direction),
                severity: .medium
            ))
        }
        if let speed = (gps[kCGImagePropertyGPSSpeed] as? NSNumber)?.doubleValue {
            out.append(.init(
                category: .location,
                label: "Speed",
                value: String(format: "%.1f km/h", speed),
                severity: .high
            ))
        }
        return out
    }

    private static func extractTIFF(_ tiff: [CFString: Any]) -> [MetadataField] {
        var out: [MetadataField] = []
        if let make = tiff[kCGImagePropertyTIFFMake] as? String {
            out.append(.init(category: .device, label: "Camera make", value: make, severity: .medium))
        }
        if let model = tiff[kCGImagePropertyTIFFModel] as? String {
            out.append(.init(category: .device, label: "Camera model", value: model, severity: .medium))
        }
        if let software = tiff[kCGImagePropertyTIFFSoftware] as? String {
            out.append(.init(category: .authoring, label: "Editing software", value: software, severity: .medium))
        }
        if let dateTime = tiff[kCGImagePropertyTIFFDateTime] as? String {
            out.append(.init(category: .capture, label: "File timestamp", value: dateTime, severity: .medium))
        }
        if let artist = tiff[kCGImagePropertyTIFFArtist] as? String, !artist.isEmpty {
            out.append(.init(category: .authoring, label: "Artist", value: artist, severity: .high))
        }
        if let copyright = tiff[kCGImagePropertyTIFFCopyright] as? String, !copyright.isEmpty {
            out.append(.init(category: .authoring, label: "Copyright", value: copyright, severity: .high))
        }
        return out
    }

    private static func extractExif(_ exif: [CFString: Any]) -> [MetadataField] {
        var out: [MetadataField] = []
        if let date = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            out.append(.init(category: .capture, label: "Captured", value: date, severity: .medium))
        }
        if let lensMake = exif[kCGImagePropertyExifLensMake] as? String, !lensMake.isEmpty {
            out.append(.init(category: .device, label: "Lens make", value: lensMake, severity: .medium))
        }
        if let lensModel = exif[kCGImagePropertyExifLensModel] as? String, !lensModel.isEmpty {
            out.append(.init(category: .device, label: "Lens model", value: lensModel, severity: .medium))
        }
        if let bodySerial = exif[kCGImagePropertyExifBodySerialNumber] as? String, !bodySerial.isEmpty {
            out.append(.init(category: .device, label: "Camera serial number", value: bodySerial, severity: .high))
        }
        if let lensSerial = exif[kCGImagePropertyExifLensSerialNumber] as? String, !lensSerial.isEmpty {
            out.append(.init(category: .device, label: "Lens serial number", value: lensSerial, severity: .high))
        }
        if let owner = exif[kCGImagePropertyExifCameraOwnerName] as? String, !owner.isEmpty {
            out.append(.init(category: .device, label: "Camera owner", value: owner, severity: .high))
        }
        if let userComment = exif[kCGImagePropertyExifUserComment] as? String, !userComment.isEmpty {
            out.append(.init(category: .authoring, label: "User comment", value: userComment, severity: .medium))
        }
        if let iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber])?.first?.intValue {
            out.append(.init(category: .capture, label: "ISO", value: "\(iso)", severity: .low))
        }
        if let fnum = (exif[kCGImagePropertyExifFNumber] as? NSNumber)?.doubleValue {
            out.append(.init(
                category: .capture,
                label: "Aperture",
                value: String(format: "f/%.1f", fnum),
                severity: .low
            ))
        }
        if let exposure = (exif[kCGImagePropertyExifExposureTime] as? NSNumber)?.doubleValue {
            out.append(.init(
                category: .capture,
                label: "Shutter speed",
                value: self.formatExposure(exposure),
                severity: .low
            ))
        }
        if let focal = (exif[kCGImagePropertyExifFocalLength] as? NSNumber)?.doubleValue {
            out.append(.init(
                category: .capture,
                label: "Focal length",
                value: String(format: "%.1f mm", focal),
                severity: .low
            ))
        }
        return out
    }

    private static func extractMakerNotes(_ props: [CFString: Any]) -> [MetadataField] {
        var out: [MetadataField] = []
        if let apple = props[kCGImagePropertyMakerAppleDictionary] as? [CFString: Any], !apple.isEmpty {
            let pairingNote = apple["17" as CFString] != nil ? " · includes Live Photo pairing UUID" : ""
            out.append(.init(
                category: .identity,
                label: "Apple MakerNote",
                value: "\(apple.count) Apple-internal field\(apple.count == 1 ? "" : "s")\(pairingNote)",
                severity: .high
            ))
        }
        let others: [(CFString, String)] = [
            (kCGImagePropertyMakerNikonDictionary, "Nikon"),
            (kCGImagePropertyMakerCanonDictionary, "Canon"),
            (kCGImagePropertyMakerFujiDictionary, "Fujifilm"),
            (kCGImagePropertyMakerOlympusDictionary, "Olympus"),
            (kCGImagePropertyMakerPentaxDictionary, "Pentax"),
            (kCGImagePropertyMakerMinoltaDictionary, "Minolta"),
            // Sony has no ImageIO constant; match its raw dictionary key so a Sony
            // MakerNote isn't silently reported as "already clean".
            ("{MakerSony}" as CFString, "Sony")
        ]
        for (key, brand) in others {
            if let dict = props[key] as? [CFString: Any], !dict.isEmpty {
                out.append(.init(
                    category: .identity,
                    label: "\(brand) MakerNote",
                    value: "\(dict.count) maker-specific field\(dict.count == 1 ? "" : "s")",
                    severity: .high
                ))
            }
        }
        return out
    }

    private static func summarise(
        _ dict: [CFString: Any],
        label: String,
        category: MetadataCategory,
        severity: MetadataSeverity
    ) -> MetadataField {
        let keys = dict.keys.map { String($0) }.sorted().prefix(6).joined(separator: ", ")
        let suffix = dict.count > 6 ? "…" : ""
        return .init(
            category: category,
            label: "\(label) (\(dict.count) field\(dict.count == 1 ? "" : "s"))",
            value: keys + suffix,
            severity: severity
        )
    }

    private static func formatExposure(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        if seconds < 1 {
            return "1/\(Int((1.0 / seconds).rounded())) s"
        }
        return String(format: "%.1f s", seconds)
    }
}

// MARK: - Video

extension MetadataInspector {
    private static func inspectVideo(url: URL) async throws -> MetadataInspection {
        let asset = AVURLAsset(url: url)
        var fields: [MetadataField] = []
        var seen: Set<String> = []

        func append(_ field: MetadataField) {
            let key = "\(field.category.rawValue)|\(field.label)|\(field.value)"
            if seen.insert(key).inserted { fields.append(field) }
        }

        for item in try await asset.load(.commonMetadata) + asset.load(.metadata) {
            if let field = await self.mapVideoItem(item) { append(field) }
        }

        for track in try await asset.load(.tracks) {
            if track.mediaType == .metadata {
                append(.init(
                    category: .identity,
                    label: "Timed-metadata track",
                    value: "Carries identifying data alongside the video",
                    severity: .high
                ))
            }
            let trackMetadata = await (try? track.load(.metadata)) ?? []
            for item in trackMetadata {
                if let field = await self.mapVideoItem(item) { append(field) }
            }
        }

        // Location user-data boxes (3GPP `loci`, QuickTime `©xyz`/`gps `) that
        // AVFoundation's metadata API doesn't surface — otherwise a video with a
        // `loci` GPS box would be reported as carrying nothing identifying.
        for box in MetadataAuditor.locationBoxes(in: url) {
            append(.init(
                category: .location,
                label: "GPS location (\(box.trimmingCharacters(in: .whitespaces)) box)",
                value: "Location metadata stored in the video container",
                severity: .high
            ))
        }

        return MetadataInspection(fields: fields)
    }

    private static func mapVideoItem(_ item: AVMetadataItem) async -> MetadataField? {
        let identifier = item.identifier?.rawValue ?? ""
        let stringValue = try? await item.load(.stringValue)
        let dateValue = try? await item.load(.dateValue)

        switch identifier {
        case "mdta/com.apple.quicktime.location.ISO6709",
             "udta/\u{00A9}xyz",
             AVMetadataIdentifier.commonIdentifierLocation.rawValue:
            guard let value = stringValue, !value.isEmpty else { return nil }
            return .init(category: .location, label: "GPS (ISO 6709)", value: value, severity: .high)
        case "mdta/com.apple.quicktime.creationdate",
             AVMetadataIdentifier.commonIdentifierCreationDate.rawValue:
            if let date = dateValue {
                let formatter = ISO8601DateFormatter()
                return .init(
                    category: .capture,
                    label: "Created",
                    value: formatter.string(from: date),
                    severity: .medium
                )
            } else if let value = stringValue, !value.isEmpty {
                return .init(category: .capture, label: "Created", value: value, severity: .medium)
            }
            return nil
        case "mdta/com.apple.quicktime.make",
             AVMetadataIdentifier.commonIdentifierMake.rawValue:
            guard let value = stringValue, !value.isEmpty else { return nil }
            return .init(category: .device, label: "Make", value: value, severity: .medium)
        case "mdta/com.apple.quicktime.model",
             AVMetadataIdentifier.commonIdentifierModel.rawValue:
            guard let value = stringValue, !value.isEmpty else { return nil }
            return .init(category: .device, label: "Model", value: value, severity: .medium)
        case "mdta/com.apple.quicktime.software",
             AVMetadataIdentifier.commonIdentifierSoftware.rawValue:
            guard let value = stringValue, !value.isEmpty else { return nil }
            return .init(category: .authoring, label: "Software", value: value, severity: .medium)
        case "mdta/com.apple.quicktime.content.identifier":
            guard let value = stringValue, !value.isEmpty else { return nil }
            return .init(category: .identity, label: "Live Photo pairing ID", value: value, severity: .high)
        default:
            return nil
        }
    }
}
