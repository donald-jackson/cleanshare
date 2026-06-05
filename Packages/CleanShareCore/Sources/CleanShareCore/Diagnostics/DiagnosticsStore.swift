import Foundation

/// A one-line summary of a persisted diagnostic report, for display in the
/// Settings → Diagnostics list. Reading reports never requires MetricKit, so
/// this lives outside the `MetricKitCollector` platform guard. See PLAN.md §18.2.
public struct DiagnosticReport: Identifiable, Sendable {
    public let id: Int
    public let date: Date?
    public let summary: String

    public init(id: Int, date: Date?, summary: String) {
        self.id = id
        self.date = date
        self.summary = summary
    }
}

/// On-device store for the rolling buffer of MetricKit reports. Resolves the
/// shared App Group location and reads back the persisted JSON for display and
/// export. `MetricKitCollector` writes here; the UI reads from here. Nothing is
/// ever transmitted. See PLAN.md §18.2.
public enum DiagnosticsStore {
    static let appGroupID = "group.solutions.ddj.cleanshare"

    /// Resolves `<AppGroup>/Diagnostics/reports.json`, creating the directory if
    /// needed. Falls back to a temp directory when the App Group container is
    /// unavailable (e.g. unit tests without the entitlement), mirroring `Workspace`.
    public static func reportsFileURL() -> URL? {
        let fileManager = FileManager.default
        let base: URL = if let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            container
        } else {
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("CleanShareDiagnostics", isDirectory: true)
        }
        let dir = base.appendingPathComponent("Diagnostics", isDirectory: true)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return dir.appendingPathComponent("reports.json")
    }

    /// Returns true when at least one report has been persisted.
    public static func hasReports() -> Bool {
        !self.recentReports().isEmpty
    }

    /// Parses the persisted JSON array into display summaries, newest first.
    public static func recentReports() -> [DiagnosticReport] {
        guard
            let url = reportsFileURL(),
            let data = try? Data(contentsOf: url),
            let array = try? JSONSerialization.jsonObject(with: data) as? [Any]
        else { return [] }

        return array.enumerated().map { index, element in
            let dict = element as? [String: Any] ?? [:]
            return DiagnosticReport(
                id: index,
                date: self.parseDate(dict),
                summary: self.summarize(dict)
            )
        }
    }

    private static func parseDate(_ dict: [String: Any]) -> Date? {
        guard let raw = dict["timeStampEnd"] as? String ?? dict["timeStampBegin"] as? String else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.date(from: raw)
    }

    private static func summarize(_ dict: [String: Any]) -> String {
        if dict["crashDiagnostics"] != nil { return "Crash report" }
        if dict["hangDiagnostics"] != nil { return "App hang report" }
        if dict["cpuExceptionDiagnostics"] != nil { return "CPU exception report" }
        if dict["diskWriteExceptionDiagnostics"] != nil { return "Disk write exception report" }
        if dict["appLaunchMetrics"] != nil || dict["cpuMetrics"] != nil { return "Performance metrics" }
        return "Diagnostic report"
    }
}
