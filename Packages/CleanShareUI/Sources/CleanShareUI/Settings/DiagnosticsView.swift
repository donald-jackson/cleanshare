import CleanShareCore
import SwiftUI

/// Settings → Diagnostics detail. Lists the five most recent on-device MetricKit
/// reports and offers a manual export of the raw JSON via the system share sheet.
/// Nothing is ever transmitted automatically. See PLAN.md §18.2.
public struct DiagnosticsView: View {
    @State private var reports: [DiagnosticReport] = []
    @State private var isExporting = false

    public init() {}

    public var body: some View {
        List {
            self.reportsSection
            self.exportSection
        }
        .navigationTitle("Diagnostics")
        .onAppear { self.reports = DiagnosticsStore.recentReports() }
    }

    private var reportsSection: some View {
        Section {
            if self.reports.isEmpty {
                Text("No reports yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.reports) { report in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.summary)
                        Text(self.dateLabel(for: report))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Recent reports")
        } footer: {
            Text(
                "Up to the five most recent crash and performance reports "
                    + "collected by MetricKit, stored on this device only."
            )
        }
    }

    private var exportSection: some View {
        Section {
            Button("Export Last 5 Crash Reports") {
                self.isExporting = true
            }
            .disabled(self.reports.isEmpty)
        }
        #if canImport(UIKit)
        .sheet(isPresented: self.$isExporting) {
            if let url = DiagnosticsStore.reportsFileURL() {
                DiagnosticsShareSheet(items: [url])
            }
        }
        #endif
    }

    private func dateLabel(for report: DiagnosticReport) -> String {
        guard let date = report.date else { return "Date unavailable" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

#if canImport(UIKit)
import UIKit

/// Minimal `UIActivityViewController` bridge so the diagnostics JSON can be
/// exported via AirDrop, Mail, Files, etc. Mirrors the host app's `ActivityView`.
struct DiagnosticsShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: self.items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
#endif
