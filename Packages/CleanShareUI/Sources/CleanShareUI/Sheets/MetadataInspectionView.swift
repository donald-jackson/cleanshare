import CleanShareCore
import SwiftUI

/// Sheet that loads `MetadataInspector` against a single file and renders the
/// identifying fields it found, grouped by category with severity colours.
///
/// Optional `onCleanAndShare` runs the file through the regular cleaning
/// pipeline and presents the share sheet — same code path as RootView's
/// "Clean photos…" flow, but invoked one-tap from the inspector so the user
/// can act on what they just saw.
public struct MetadataInspectionView: View {
    private let url: URL
    private let kind: MediaKind
    private let onCleanAndShare: (() -> Void)?
    @State private var loadState: LoadState = .loading
    @Environment(\.dismiss) private var dismiss

    public init(url: URL, kind: MediaKind, onCleanAndShare: (() -> Void)? = nil) {
        self.url = url
        self.kind = kind
        self.onCleanAndShare = onCleanAndShare
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    self.headerCard
                    self.contentBody
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(BrandPalette.paper.ignoresSafeArea())
            .navigationTitle(String(localized: "What's in this file"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { self.dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                self.cleanAndShareBar
            }
            .task { await self.load() }
        }
    }

    private enum LoadState {
        case loading
        case loaded(MetadataInspection)
        case failed(Error)
    }

    @MainActor
    private func load() async {
        do {
            let inspection = try await MetadataInspector.inspect(url: self.url, kind: self.kind)
            self.loadState = .loaded(inspection)
        } catch {
            self.loadState = .failed(error)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(BrandPalette.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "If you share this without CleanShare…"))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(BrandPalette.ink)
                    Text(self.headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.indigo.opacity(0.10), lineWidth: 1)
        )
    }

    private var headerSubtitle: String {
        switch self.loadState {
        case .loading:
            return String(localized: "Reading metadata…")
        case .loaded(let inspection):
            if inspection.fields.isEmpty {
                return String(localized: "Nothing identifying. This file is already clean.")
            }
            let count = inspection.identifyingCount
            return count == 1
                ? String(localized: "the recipient gets 1 identifying field.")
                : String(localized: "the recipient gets \(count) identifying fields.")
        case .failed:
            return String(localized: "Couldn't read this file.")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentBody: some View {
        switch self.loadState {
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text(String(localized: "Reading metadata…"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .loaded(let inspection):
            if inspection.fields.isEmpty {
                self.emptyState
            } else {
                ForEach(inspection.byCategory, id: \.category) { entry in
                    self.section(category: entry.category, fields: entry.fields)
                }
            }
        case .failed(let error):
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Couldn't read this file."))
                    .font(.headline)
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(BrandPalette.teal)
            Text(String(localized: "No identifying metadata found"))
                .font(.system(.headline, design: .rounded, weight: .semibold))
            Text(
                String(
                    localized: "Either it was already stripped, or this file format doesn't carry the usual fields. You can share it as-is."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func section(category: MetadataCategory, fields: [MetadataField]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(category.title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                    self.fieldRow(field)
                    if index < fields.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fieldRow(_ field: MetadataField) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(self.severityColor(field.severity))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(field.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BrandPalette.ink)
                Text(field.value)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func severityColor(_ severity: MetadataSeverity) -> Color {
        switch severity {
        case .high: Color(red: 0.86, green: 0.20, blue: 0.27)
        case .medium: Color(red: 0.94, green: 0.55, blue: 0.16)
        case .low: BrandPalette.indigo.opacity(0.55)
        }
    }

    // MARK: - Clean & share CTA

    @ViewBuilder
    private var cleanAndShareBar: some View {
        if case .loaded(let inspection) = self.loadState,
           !inspection.fields.isEmpty,
           let onCleanAndShare = self.onCleanAndShare {
            VStack(spacing: 0) {
                Divider()
                Button {
                    onCleanAndShare()
                    self.dismiss()
                } label: {
                    Label(String(localized: "Clean and share"), systemImage: "wand.and.stars")
                }
                .buttonStyle(CleanSharePrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }
}
