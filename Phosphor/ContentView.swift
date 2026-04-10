import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView()
            }

            Tab("Lists", systemImage: "list.bullet.rectangle.fill") {
                FilterListsView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(PhosphorTheme.accent)
    }
}

#Preview {
    ContentView()
}
