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
    public static let shared = MetricKitCollector(appGroupID: "group.solutions.ddj.cleanshare")

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
        self.shared.startIfNeeded()
    }

    /// Removes the shared collector from `MXMetricManager`. No-op if not subscribed.
    public static func unsubscribe() {
        self.shared.stopIfNeeded()
    }

    private func startIfNeeded() {
        guard !self.isSubscribed else { return }
        MXMetricManager.shared.add(self)
        self.isSubscribed = true
    }

    private func stopIfNeeded() {
        guard self.isSubscribed else { return }
        MXMetricManager.shared.remove(self)
        self.isSubscribed = false
    }

    // MARK: - MXMetricManagerSubscriber

    public func didReceive(_ payloads: [MXMetricPayload]) {
        self.persist(payloads.map { $0.jsonRepresentation() })
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        self.persist(payloads.map { $0.jsonRepresentation() })
    }

    // MARK: - Persistence

    private func persist(_ newReports: [Data]) {
        guard !newReports.isEmpty, let url = reportsURL() else { return }

        let incoming = newReports.compactMap { try? JSONSerialization.jsonObject(with: $0) }
        guard !incoming.isEmpty else { return }

        var reports = self.loadReports(at: url)
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

    /// Resolves `<AppGroup>/Diagnostics/reports.json`. The path logic lives in
    /// `DiagnosticsStore` so the read-side UI and export share one source of truth.
    private func reportsURL() -> URL? {
        DiagnosticsStore.reportsFileURL()
    }
}
#endif
