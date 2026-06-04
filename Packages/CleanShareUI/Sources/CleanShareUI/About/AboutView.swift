import SwiftUI

/// App information screen. Fleshed out with version, privacy, source, and
/// supported-formats sections in task 4.09; this scaffold lets `SettingsView`
/// link to it. See PLAN.md §14.
public struct AboutView: View {
    public init() {}

    public var body: some View {
        List {
            Text("About CleanShare")
        }
        .navigationTitle("About")
    }
}
