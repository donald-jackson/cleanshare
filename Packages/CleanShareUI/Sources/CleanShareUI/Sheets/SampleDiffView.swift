import ImageIO
import SwiftUI

/// Side-by-side BEFORE / AFTER metadata diff for the "Try it on a sample photo"
/// flow. Reads the top-level CGImageSource property dictionary of each file and
/// renders it as monospaced `key: value` lines, colouring identifying keys red.
/// `afterURL == nil` renders an empty AFTER column (e.g. cleaning not yet run).
/// See PLAN.md §3.3.
public struct SampleDiffView: View {
    private let beforeURL: URL
    private let afterURL: URL?

    /// Top-level property keys that carry identifying information. Any presence
    /// is flagged red. Mirrors the dictionaries in `MetadataAuditor`.
    private static let sensitiveKeys: Set<String> = [
        "{Exif}", "{ExifAux}", "{GPS}", "{IPTC}", "{IPTCXMP}", "{XMP}",
        "{Photoshop}", "{TIFF}", "{MakerApple}", "{MakerNikon}",
        "{MakerCanon}", "{MakerFuji}", "{MakerOlympus}", "{MakerPentax}",
        "{MakerSony}",
    ]

    public init(beforeURL: URL, afterURL: URL?) {
        self.beforeURL = beforeURL
        self.afterURL = afterURL
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            column(title: "Before", url: beforeURL)
            Divider()
            column(title: "After cleaning", url: afterURL)
        }
    }

    private func column(title: String, url: URL?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .bold()
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Self.lines(for: url), id: \.key) { entry in
                        Text("\(entry.key): \(entry.value)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(entry.sensitive ? Color.red : Color.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Entry {
        let key: String
        let value: String
        let sensitive: Bool
    }

    private static func lines(for url: URL?) -> [Entry] {
        properties(for: url)
            .sorted { $0.key < $1.key }
            .map { key, value in
                Entry(
                    key: key,
                    value: String(describing: value),
                    sensitive: sensitiveKeys.contains(key)
                )
            }
    }

    private static func properties(for url: URL?) -> [String: Any] {
        guard
            let url,
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: props.map { (String($0.key), $0.value) })
    }
}
