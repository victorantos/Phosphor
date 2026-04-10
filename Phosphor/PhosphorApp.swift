import PhosphorShared
import SwiftUI

@main
struct PhosphorApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        importBundledListsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }

    private func importBundledListsIfNeeded() {
        let store = FilterListStore()
        let loader = BundledListLoader(store: store)
        guard !loader.hasImported else { return }
        Task.detached(priority: .utility) {
            try? loader.importIfNeeded()
        }
    }
}
