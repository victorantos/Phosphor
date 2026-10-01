import NetworkExtension
import PhosphorShared
import SwiftUI

@main
struct PhosphorApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var subscriptionManager = SubscriptionManager()
    @State private var showPaywall = false
    @Environment(\.scenePhase) private var scenePhase

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
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active else { return }
                Task {
                    await FilterPause.reconcile()
                    await FilterParsing.updateSavedConfiguration()
                    await FilterRefresher.restartIfStopped()
                    await skipOnboardingIfFilterIsRunning()
                    await FilterProbe.runIfRequested()
                }
            }
            // Phosphor is a dark-only brand: warm black with one light on it.
            // A light rendering would have nothing for the phosphor to glow against.
            .preferredColorScheme(.dark)
            .tint(PhosphorTheme.phosphor)
        }
    }

    /// Setup is re-entered by resetting onboarding. If the app is closed before the last
    /// screen is dismissed, the filter is on but onboarding would show again.
    private func skipOnboardingIfFilterIsRunning() async {
        guard !hasCompletedOnboarding else { return }
        let manager = NEURLFilterManager.shared
        guard (try? await manager.loadFromPreferences()) != nil, manager.isEnabled else { return }
        // The status reads as invalid for a moment after loading, so let it settle.
        // `starting` counts: a filter that is starting again, for example after an
        // update, has been set up all the same.
        for _ in 0..<6 {
            let status = await manager.status
            if status == .running || status == .starting {
                hasCompletedOnboarding = true
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func importBundledListsIfNeeded() {
        let store = FilterListStore()
        let loader = BundledListLoader(store: store)
        guard !loader.hasImported else { return }
        Task.detached(priority: .utility) {
            try? loader.importIfNeeded()
            // An update can bring new lists; make the running filter pick them up.
            await FilterRefresher.listsChanged()
        }
    }
}
