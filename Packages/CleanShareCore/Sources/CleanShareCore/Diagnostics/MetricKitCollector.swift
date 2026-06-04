#if canImport(MetricKit)
import Foundation
import MetricKit

/// Opt-in, on-device MetricKit sink. Subscribes to `MXMetricManager` only when
/// the user enables the Diagnostics row in Settings, serializes each received
/// payload to JSON, and keeps a rolling buffer of the last five reports in the
/// App Group container. Nothing is ever transmitted — export is a manual user
/// action elsewhere in the UI. See PLAN.md §18.2.
@MainActor
public final class MetricKitCollector: NSObject, @MainActor MXMetricManagerSubscriber {
    /// Process-wide singleton so `subscribe()` / `unsubscribe()` are idempotent.
    public static let shared = MetricKitCollector(appGroupID: "group.dev.cleanshare.app")

    private static let maxReports = 5

    private let appGroupID: String
    private var isSubscribed = false

    init(appGroupID: String) {
        self.appGroupID = appGroupID
        super.init()
    }

    /// Registers the shared collector with `MXMetricManager`. Idempotent — calling
    /// it more than once registers the subscriber exactly once.
    public static func subscribe() {
        shared.startIfNeeded()
    }

    /// Removes the shared collector from `MXMetricManager`. No-op if not subscribed.
    public static func unsubscribe() {
        shared.stopIfNeeded()
    }

    private func startIfNeeded() {
        guard !isSubscribed else { return }
        MXMetricManager.shared.add(self)
        isSubscribed = true
    }

    private func stopIfNeeded() {
        guard isSubscribed else { return }
        MXMetricManager.shared.remove(self)
        isSubscribed = false
    }

    // MARK: - MXMetricManagerSubscriber

    public func didReceive(_ payloads: [MXMetricPayload]) {
        persist(payloads.map { $0.jsonRepresentation() })
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        persist(payloads.map { $0.jsonRepresentation() })
    }

    // MARK: - Persistence

    private func persist(_ newReports: [Data]) {
        guard !newReports.isEmpty, let url = reportsURL() else { return }

        let incoming = newReports.compactMap { try? JSONSerialization.jsonObject(with: $0) }
        guard !incoming.isEmpty else { return }

        var reports = loadReports(at: url)
        reports.insert(contentsOf: incoming, at: 0)
        if reports.count > Self.maxReports {
            reports = Array(reports.prefix(Self.maxReports))
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: reports,
            options: [.prettyPrinted]
        ) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadReports(at url: URL) -> [Any] {
        guard
            let data = try? Data(contentsOf: url),
            let array = try? JSONSerialization.jsonObject(with: data) as? [Any]
        else { return [] }
        return array
    }

    /// Resolves `<AppGroup>/Diagnostics/reports.json`, creating the directory if
    /// needed. Falls back to a temp directory when the App Group container is
    /// unavailable (e.g. unit tests without the entitlement), mirroring `Workspace`.
    private func reportsURL() -> URL? {
        let fm = FileManager.default
        let base: URL
        if let container = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            base = container
        } else {
            base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("CleanShareDiagnostics", isDirectory: true)
        }
        let dir = base.appendingPathComponent("Diagnostics", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return dir.appendingPathComponent("reports.json")
    }
}
#endif
