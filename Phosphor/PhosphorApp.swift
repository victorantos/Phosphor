import PhosphorShared
import SwiftUI

@main
struct PhosphorApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var subscriptionManager = SubscriptionManager()
    @State private var showPaywall = false

    init() {
        importBundledListsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else {
                    ContentView()
                        .sheet(isPresented: $showPaywall) {
                            PaywallView()
                        }
                        .onAppear {
                            Task {
                                await subscriptionManager.updateSubscriptionStatus()
                                if !subscriptionManager.isSubscribed {
                                    showPaywall = true
                                }
                            }
                        }
                        .onChange(of: subscriptionManager.isSubscribed) { _, isSubscribed in
                            if isSubscribed {
                                showPaywall = false
                            }
                        }
                }
            }
            .environment(subscriptionManager)
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
