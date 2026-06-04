import Foundation

/// Bridges the URL-scheme handoff into SwiftUI. `HandoffRouter` posts the cleaned
/// output URLs here; `RootView` observes `pendingURLs` to present the system share
/// sheet. See PLAN.md §6.
@MainActor
final class ShareSheetCoordinator: ObservableObject {
    @Published var pendingURLs: [URL]?
}
