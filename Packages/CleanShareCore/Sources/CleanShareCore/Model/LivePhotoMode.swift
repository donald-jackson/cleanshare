/// How CleanShare handles Live Photos (a still + paired motion video). See
/// PLAN.md §4.5/§4.6. The engine never receives `.prompt`; the UI resolves it.
public enum LivePhotoMode: String, Sendable, Codable, CaseIterable {
    case prompt
    case downgradeToStill
    case preservePairing
    case repairWithFreshID
}
