import SwiftUI

/// The three top-level destinations. Held as state so one screen can send the
/// reader to another — the dashboard's "active lists" row opens the Lists tab.
enum PhosphorTab: Hashable {
    case dashboard, lists, settings
}

struct ContentView: View {
    @State private var selection: PhosphorTab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            Tab("Dashboard", systemImage: "chart.bar.fill", value: PhosphorTab.dashboard) {
                DashboardView(selection: $selection)
            }

            Tab("Lists", systemImage: "list.bullet.rectangle.fill", value: PhosphorTab.lists) {
                FilterListsView()
            }

            Tab("Settings", systemImage: "slider.horizontal.3", value: PhosphorTab.settings) {
                SettingsView()
            }
        }
        .tint(PhosphorTheme.phosphor)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
