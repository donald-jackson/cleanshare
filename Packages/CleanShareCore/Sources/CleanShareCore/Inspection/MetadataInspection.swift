import Foundation

/// Result of `MetadataInspector.inspect(url:kind:)`. An empty `fields` list
/// means the file carries nothing identifying.
public struct MetadataInspection: Sendable {
    public let fields: [MetadataField]

    public init(fields: [MetadataField]) {
        self.fields = fields
    }

    public var isEmpty: Bool {
        self.fields.isEmpty
    }

    /// Number of fields whose severity counts as "would identify the user"
    /// (high or medium). Drives the inspector view's headline summary.
    public var identifyingCount: Int {
        self.fields.count { $0.severity != .low }
    }

    /// Groups the fields by category in the canonical UI order. Categories
    /// with no fields are dropped.
    public var byCategory: [(category: MetadataCategory, fields: [MetadataField])] {
        MetadataCategory.allCases.compactMap { category in
            let matching = self.fields.filter { $0.category == category }
            return matching.isEmpty ? nil : (category, matching)
        }
    }
}

/// One identifiable metadata field surfaced by the inspector. `label` and
/// `value` are pre-formatted for direct display.
public struct MetadataField: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let category: MetadataCategory
    public let label: String
    public let value: String
    public let severity: MetadataSeverity

    public init(
        id: UUID = UUID(),
        category: MetadataCategory,
        label: String,
        value: String,
        severity: MetadataSeverity
    ) {
        self.id = id
        self.category = category
        self.label = label
        self.value = value
        self.severity = severity
    }
}

/// Coarse grouping that drives the section headers in the inspector view.
public enum MetadataCategory: String, Sendable, CaseIterable, Hashable {
    /// GPS, altitude, speed, direction — anything tying the file to a place.
    case location
    /// Camera/lens make, model, owner, serial number.
    case device
    /// Capture date, exposure settings.
    case capture
    /// MakerNote dictionaries, Live Photo pairing IDs — opaque correlatable
    /// tokens that aren't directly PII but are unique to the device or asset.
    case identity
    /// IPTC, XMP, Photoshop, artist, copyright, user comments — editor and
    /// authorship trails.
    case authoring

    /// Title shown in the inspector section header.
    public var title: String {
        switch self {
        case .location: "Where it was taken"
        case .device: "Which device took it"
        case .capture: "When and how"
        case .identity: "Device-internal identifiers"
        case .authoring: "Editor trail"
        }
    }
}

/// Loose ranking of how identifying a field is. Drives colour in the
/// inspector view.
public enum MetadataSeverity: String, Sendable, Hashable {
    /// GPS coords, content identifier, serial numbers — pinpoint identity.
    case high
    /// Camera model, capture date, software, lens — narrows identity.
    case medium
    /// Exposure, ISO, aperture — fingerprinting risk, but not directly PII.
    /// CleanShare keeps these by default for power users; the inspector
    /// shows them so the user knows they're in there.
    case low
}
