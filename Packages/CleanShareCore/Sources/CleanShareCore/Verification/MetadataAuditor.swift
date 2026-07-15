import AVFoundation
import Foundation
import ImageIO

/// Fail-closed verification: after a cleaner finalizes its output, the auditor
/// re-reads the file and reports any sensitive metadata that survived but was
/// not explicitly allowed. An empty result means clean. See PLAN.md §8.1.
public enum MetadataAuditor {
    /// Metadata dictionaries that are entirely identifying: any presence at all
    /// (unless explicitly allowed) is a leak.
    static let alwaysSensitive: Set<String> = [
        "{ExifAux}", "{GPS}", "{IPTC}", "{IPTCXMP}", "{XMP}", "{Photoshop}",
        "{MakerApple}", "{MakerNikon}", "{MakerCanon}", "{MakerFuji}",
        "{MakerOlympus}", "{MakerPentax}", "{MakerMinolta}", "{MakerSony}"
    ]

    /// Mixed dictionaries that ImageIO unavoidably regenerates from the pixel
    /// data (colour space, dimensions, density, etc.). They are only a leak if
    /// they carry a key *beyond* this structural-safe allowlist — so a stripped
    /// JPEG's `{Exif}` of `ColorSpace`/`PixelXDimension` is clean, but a lingering
    /// `UserComment` or `DateTimeOriginal` is flagged. See PLAN.md §8.1.
    static let structuralSafeKeys: [String: Set<String>] = [
        "{Exif}": ["ColorSpace", "PixelXDimension", "PixelYDimension",
                   "ComponentsConfiguration", "ExifVersion", "FlashPixVersion", "SceneType"],
        "{TIFF}": ["Orientation", "ResolutionUnit", "XResolution", "YResolution",
                   "PhotometricInterpretation", "SamplesPerPixel", "Compression", "RowsPerStrip",
                   "TileWidth", "TileLength"],
        "{JFIF}": ["JFIFVersion", "XDensity", "YDensity", "DensityUnit", "IsProgressive"],
        "{PNG}": ["InterlaceType", "Gamma", "sRGBIntent", "Chromaticities",
                  "PixelAspectRatio", "XPixelsPerMeter", "YPixelsPerMeter"],
        "{HEICS}": ["LoopCount", "DelayTime", "UnclampedDelayTime",
                    "CanvasPixelWidth", "CanvasPixelHeight"]
    ]

    /// The Live Photo pairing token — the one video metadata identifier a caller
    /// may legitimately preserve (via `.preservePairing`). See PLAN.md §4.5.
    public static let livePhotoContentIdentifier = "mdta/com.apple.quicktime.content.identifier"

    /// Re-opens `url` and returns the sorted list of sensitive metadata keys that
    /// leaked through (present in the output and not in `allowing`). Every frame
    /// of a multi-frame image is checked, and an unreadable frame is itself a
    /// leak (fail closed — we never certify a file we could not inspect).
    public static func audit(url: URL, kind: MediaKind, allowing allowlist: Set<String>) throws -> [String] {
        switch kind {
        case .mp4, .mov, .livePhoto:
            // Video is audited asynchronously via `auditVideo(url:allowing:)`
            // because AVFoundation metadata loading is async.
            return []
        default:
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                throw CleanerError.unreadable
            }

            var leaks: Set<String> = []
            let frameCount = max(CGImageSourceGetCount(src), 1)
            for frameIndex in 0 ..< frameCount {
                guard let props = CGImageSourceCopyPropertiesAtIndex(src, frameIndex, nil) as? [CFString: Any] else {
                    // Could not read this frame's properties — refuse to certify it.
                    leaks.insert("unverifiable-frame-\(frameIndex)")
                    continue
                }

                for (rawKey, value) in props {
                    let key = String(describing: rawKey)
                    if allowlist.contains(key) { continue }

                    if self.alwaysSensitive.contains(key) {
                        leaks.insert(key)
                    } else if let safe = structuralSafeKeys[key] {
                        guard let dict = value as? [CFString: Any] else {
                            leaks.insert(key) // unexpected shape — fail closed
                            continue
                        }
                        let subKeys = Set(dict.keys.map { String(describing: $0) })
                        let identifying = subKeys.subtracting(safe).subtracting(allowlist)
                        if !identifying.isEmpty { leaks.insert(key) }
                    }
                }
            }
            return leaks.sorted()
        }
    }

    /// Re-opens a cleaned MP4/MOV/Live-Photo video at `url` and returns the sorted
    /// list of sensitive metadata that survived.
    ///
    /// The check is **allowlist-inverted**: a correctly cleaned video exposes *no*
    /// container/track metadata at all, so the presence of *any* metadata item —
    /// not just a hardcoded set of Apple identifiers — is treated as residue
    /// unless the caller explicitly allowed it. This catches encoder tags
    /// (`©too`), titles, comments, authorship, dates, make/model and GPS `©xyz`
    /// alike. A timed-metadata track is itself a leak.
    ///
    /// AVFoundation's metadata API does not surface the 3GPP `loci` box (or a bare
    /// QuickTime `©xyz`/`gps ` user-data box), so those are additionally scanned
    /// straight from the box tree by `locationBoxes(in:)`. See PLAN.md §4.3, §8.1.
    public static func auditVideo(url: URL, allowing allowlist: Set<String>) async throws -> [String] {
        let asset = AVURLAsset(url: url)

        var leaks: Set<String> = []
        var items: [AVMetadataItem] = []
        items += try await asset.load(.commonMetadata)
        items += try await asset.load(.metadata)
        for format in try await asset.load(.availableMetadataFormats) {
            await items += (try? asset.loadMetadata(for: format)) ?? []
        }

        let tracks = try await asset.load(.tracks)
        for track in tracks {
            if track.mediaType == .metadata { leaks.insert("timed-metadata-track") }
            items += try await track.load(.metadata)
        }

        for item in items {
            let identifier = item.identifier?.rawValue ?? "unidentified-metadata-item"
            if !allowlist.contains(identifier) { leaks.insert(identifier) }
        }

        // Location boxes AVFoundation cannot see (scanned from the raw box tree).
        for box in self.locationBoxes(in: url) where !allowlist.contains(box) {
            leaks.insert(box)
        }

        return leaks.sorted()
    }

    // MARK: - Raw box-tree location scan

    /// User-data leaf boxes that carry location and are invisible to
    /// AVFoundation's metadata API: 3GPP `loci`, QuickTime `©xyz`, and `gps `.
    private static let sensitiveUserDataBoxes: Set<String> = ["loci", "\u{00A9}xyz", "gps "]

    /// Reads only the `moov` box (never the `mdat` media payload) and returns any
    /// location-bearing user-data box found under `moov/udta` or `moov/trak/udta`.
    /// Returns `[]` on any read/parse problem — the AVFoundation pass in
    /// `auditVideo` remains the primary check, so a malformed container can never
    /// be *certified* clean by this helper failing open.
    static func locationBoxes(in url: URL) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let moov = self.readTopLevelBoxContent(named: "moov", from: handle) else { return [] }

        var found: Set<String> = []
        self.forEachBox(in: moov) { type, content in
            switch type {
            case "udta":
                self.collectSensitiveLeaves(in: content, into: &found)
            case "trak":
                self.forEachBox(in: content) { inner, innerContent in
                    if inner == "udta" { self.collectSensitiveLeaves(in: innerContent, into: &found) }
                }
            default:
                break
            }
        }
        return found.sorted()
    }

    private static func collectSensitiveLeaves(in udta: [UInt8], into found: inout Set<String>) {
        self.forEachBox(in: udta) { type, _ in
            if self.sensitiveUserDataBoxes.contains(type) { found.insert(type) }
        }
    }

    /// Iterates the top-level box list via the file handle and returns the content
    /// bytes (header stripped) of the first box whose type matches `name`. Only
    /// that one box is read into memory; the media payload is skipped by seeking.
    private static func readTopLevelBoxContent(named name: String, from handle: FileHandle) -> [UInt8]? {
        guard let fileSize = try? handle.seekToEnd() else { return nil }
        var offset: UInt64 = 0
        while offset + 8 <= fileSize {
            guard (try? handle.seek(toOffset: offset)) != nil,
                  let header = try? handle.read(upToCount: 8), header.count == 8 else { return nil }
            let bytes = [UInt8](header)
            var size = UInt64(self.beUInt32(bytes, 0))
            let type = self.fourCC(bytes, 4)
            var headerSize: UInt64 = 8
            if size == 1 {
                guard let ext = try? handle.read(upToCount: 8), ext.count == 8 else { return nil }
                size = self.beUInt64([UInt8](ext), 0)
                headerSize = 16
            } else if size == 0 {
                size = fileSize - offset
            }
            guard size >= headerSize, offset + size <= fileSize else { return nil }
            if type == name {
                guard (try? handle.seek(toOffset: offset + headerSize)) != nil,
                      let content = try? handle.read(upToCount: Int(size - headerSize)) else { return nil }
                return [UInt8](content)
            }
            offset += size
        }
        return nil
    }

    /// Walks the immediate child boxes of an in-memory box body. Stops on the
    /// first malformed length rather than reading out of bounds.
    private static func forEachBox(in bytes: [UInt8], _ body: (String, [UInt8]) -> Void) {
        var cursor = 0
        while cursor + 8 <= bytes.count {
            var boxSize = Int(self.beUInt32(bytes, cursor))
            let type = self.fourCC(bytes, cursor + 4)
            var headerSize = 8
            if boxSize == 1 {
                guard cursor + 16 <= bytes.count else { return }
                boxSize = Int(self.beUInt64(bytes, cursor + 8))
                headerSize = 16
            } else if boxSize == 0 {
                boxSize = bytes.count - cursor
            }
            guard boxSize >= headerSize, cursor + boxSize <= bytes.count else { return }
            body(type, Array(bytes[(cursor + headerSize) ..< (cursor + boxSize)]))
            cursor += boxSize
        }
    }

    private static func beUInt32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        (UInt32(bytes[offset]) << 24) | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8) | UInt32(bytes[offset + 3])
    }

    private static func beUInt64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for shift in 0 ..< 8 {
            value = (value << 8) | UInt64(bytes[offset + shift])
        }
        return value
    }

    /// Decodes a 4-byte box type as Latin-1 so the `©` (0xA9) prefix of QuickTime
    /// user-data atoms round-trips to a comparable `String`.
    private static func fourCC(_ bytes: [UInt8], _ offset: Int) -> String {
        String((0 ..< 4).map { Character(Unicode.Scalar(bytes[offset + $0])) })
    }
}
