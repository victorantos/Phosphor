import NetworkExtension
import os
import PhosphorShared
import SwiftUI

struct SetupPage: View {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "Setup")

    @Binding var hasCompletedOnboarding: Bool
    @Binding var currentPage: Int

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var showingPaywall = false

    @State private var setupState: SetupState = .ready
    @State private var errorMessage: String?

    enum SetupState {
        case ready
        case enabling
        case success
        case failed
        case skipped
    }

    private var isSettled: Bool { setupState == .success || setupState == .skipped }

    /// How long to wait for the filter to report that it is running.
    private static let startTimeoutSeconds = 90

    var body: some View {
        OnboardingLayout {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingStepHeader(step: "Step 3 of 3") { withAnimation { currentPage = 1 } }

                Text(titleText)
                    .font(.system(size: 34, weight: .bold))
                    .kerning(-1.2)
                    .foregroundStyle(PhosphorTheme.ink50)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 14)

                Text(subtitleText)
                    .font(.system(size: 17))
                    .foregroundStyle(PhosphorTheme.ink300)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)

                if let errorMessage {
                    errorCard(errorMessage)
                        .padding(.bottom, 14)
                }

                grantsCard

                infoNote
                    .padding(.top, 14)
            }
        } footer: {
            VStack(spacing: 10) {
                PageDots(currentPage: 2)
                actionButtons
            }
        }
        // Filtering needs Premium, so the paywall comes first and setup carries on
        // once a purchase or trial has started.
        .sheet(isPresented: $showingPaywall, onDismiss: {
            if subscriptionManager.isSubscribed {
                Task { await enableFilter() }
            }
        }) {
            PaywallView()
        }
    }

    // MARK: - Copy

    private var titleText: String {
        switch setupState {
        case .ready, .failed: "Turn on the filter"
        case .enabling: "Turning it on…"
        case .success: "You're protected"
        case .skipped: "Set up later"
        }
    }

    private var subtitleText: String {
        switch setupState {
        case .ready:
            "Filtering comes with Phosphor Premium, and new subscribers get 7 days free. iOS will then ask once whether Phosphor may filter network content. Here is exactly what that grants."
        case .enabling:
            "Starting the filter. The first time can take up to a minute."
        case .success:
            "Phosphor is filtering URLs across your device. Manage what it blocks from the Lists tab."
        case .failed:
            "Something went wrong. Try again, or turn filtering on later from Settings."
        case .skipped:
            "You can turn filtering on at any time from Settings."
        }
    }

    // MARK: - What the permission grants

    private var grantsCard: some View {
        PhosphorGroup {
            grantRow(
                title: "Checks URLs against your lists",
                detail: "Locally, using a Bloom filter. Most URLs never leave the phone.",
                lit: true
            )
            PhosphorDivider(inset: 16)
            grantRow(
                title: "Sends only encrypted queries",
                detail: "Through Apple's relay. Our server cannot read them.",
                lit: true
            )
            PhosphorDivider(inset: 16)
            grantRow(
                title: "Does not read page content",
                detail: "No VPN, no traffic rerouting, no history stored anywhere.",
                lit: false
            )
        }
    }

    private func grantRow(title: String, detail: String, lit: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // A lit dot marks something the filter *does*; an unlit one marks
            // something it deliberately does not.
            Circle()
                .fill(lit ? PhosphorTheme.phosphor : PhosphorTheme.ink600)
                .frame(width: 8, height: 8)
                .shadow(color: lit ? PhosphorTheme.phosphor.opacity(0.7) : .clear, radius: 5)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink50)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(PhosphorTheme.ink400)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private var infoNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 16))
                .foregroundStyle(PhosphorTheme.ink400)
                .padding(.top, 1)

            Text("You can pause or switch this off any time in Settings. If the filter ever shows \u{201C}Invalid\u{201D}, reinstalling fixes it.")
                .font(.system(size: 14))
                .foregroundStyle(PhosphorTheme.ink300)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .fill(PhosphorTheme.ink50.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .strokeBorder(
                    PhosphorTheme.ink50.opacity(0.16),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                )
        }
        .accessibilityElement(children: .combine)
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(PhosphorTheme.signalRed)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(PhosphorTheme.ink300)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .fill(PhosphorTheme.signalRed.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .strokeBorder(PhosphorTheme.signalRed.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        switch setupState {
        case .ready, .failed:
            VStack(spacing: 4) {
                Button("Enable filtering") {
                    if subscriptionManager.isSubscribed {
                        Task { await enableFilter() }
                    } else {
                        showingPaywall = true
                    }
                }
                .buttonStyle(PhosphorPrimaryButtonStyle())

                Button {
                    withAnimation { setupState = .skipped }
                } label: {
                    Text("Not now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PhosphorTheme.ink400)
                        .frame(height: 44)
                }
            }

        case .enabling:
            HStack(spacing: 10) {
                ProgressView().tint(PhosphorTheme.ink950)
                Text("Starting the filter…")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: PhosphorTheme.controlRadius, style: .continuous)
                    .fill(PhosphorTheme.phosphor.opacity(0.5))
            }
            .foregroundStyle(PhosphorTheme.ink950)
            .font(.system(size: 17, weight: .semibold))

        case .success, .skipped:
            Button("Get started") {
                hasCompletedOnboarding = true
            }
            .buttonStyle(PhosphorPrimaryButtonStyle())
            .padding(.bottom, isSettled ? 44 : 0)
        }
    }

    // MARK: - Filter Setup

    private func enableFilter() async {
        setupState = .enabling
        errorMessage = nil
        FilterPause.clear()

        let pirURL = PIRConfiguration.serverURL

        guard let authToken = PIRConfiguration.authenticationToken else {
            errorMessage = "This build has no PIR authentication token. Add one to Config/Secrets.xcconfig and rebuild."
            withAnimation { setupState = .failed }
            return
        }

        do {
            // The extension cannot build the Bloom filter within its memory limit,
            // so it must be on disk before the system asks for it.
            let prefilter = try await Task.detached(priority: .userInitiated) {
                let store = FilterListStore()
                try BundledListLoader(store: store).importIfNeeded()
                return try PrefilterStore().rebuild(from: store)
            }.value
            Self.logger.info("Prefilter ready: \(prefilter?.urlCount ?? 0) URLs")

            let manager = NEURLFilterManager.shared

            // Remove any existing invalid configuration first
            do {
                try await manager.loadFromPreferences()
                try await manager.removeFromPreferences()
                Self.logger.info("Removed existing filter configuration")
            } catch {
                Self.logger.error("Could not remove existing configuration: \(mapError(error), privacy: .public)")
            }

            // Fresh configuration with HTTPS PIR server
            try await manager.loadFromPreferences()

            try manager.setConfiguration(
                pirServerURL: pirURL,
                pirPrivacyPassIssuerURL: pirURL,
                pirAuthenticationToken: authToken,
                controlProviderBundleIdentifier: PhosphorConstants.filterExtensionBundleID
            )

            manager.localizedDescription = "Phosphor URL Filter"
            manager.isEnabled = true
            manager.shouldFailClosed = false
            manager.prefilterFetchInterval = 86400
            FilterParsing.apply(to: manager)

            try await manager.saveToPreferences()
            Self.logger.info("Saved filter configuration for \(pirURL.absoluteString, privacy: .public)")

            // A save can succeed while the system still rejects the configuration,
            // so confirm it before telling the user they are protected.
            try await manager.loadFromPreferences()

            // Parameters cached for a previous server or token keep the filter from
            // starting, so drop them and fetch fresh ones.
            do {
                try await manager.resetPIRCache()
                Self.logger.info("Reset PIR cache")
            } catch {
                Self.logger.error("Resetting PIR cache failed: \(mapError(error), privacy: .public)")
            }
            do {
                try await manager.refreshPIRParameters()
                Self.logger.info("Refreshed PIR parameters")
            } catch {
                Self.logger.error("Refreshing PIR parameters failed: \(mapError(error), privacy: .public)")
            }

            // A first start is slow: the system fetches Privacy Pass tokens and uploads an
            // evaluation key, and gives up and retries every 10 seconds until that is done.
            var status = await manager.status
            for _ in 0..<Self.startTimeoutSeconds where status != .running {
                try? await Task.sleep(for: .seconds(1))
                status = await manager.status
            }
            Self.logger.info("Filter status after save: \(String(describing: status), privacy: .public), enabled: \(manager.isEnabled)")

            guard manager.isEnabled, status == .running else {
                let reason = await manager.lastDisconnectError
                let details = [
                    "status: \(String(describing: status))",
                    "enabled: \(manager.isEnabled)",
                    "reason: \(reason.map { "\(String(describing: $0)) (\($0.rawValue))" } ?? "none")",
                    "server: \(manager.pirServerURL?.host() ?? "nil")",
                    "provider: \(manager.controlProviderBundleIdentifier ?? "nil")",
                    "app: \(manager.appBundleIdentifier ?? "nil")",
                ].joined(separator: ", ")
                Self.logger.error("Filter configuration rejected: \(details, privacy: .public)")
                errorMessage = "The filter was saved but did not start (\(details))."
                withAnimation { setupState = .failed }
                return
            }
            withAnimation { setupState = .success }
        } catch {
            Self.logger.error("Applying filter configuration failed: \(mapError(error), privacy: .public)")
            errorMessage = mapError(error)
            withAnimation { setupState = .failed }
        }
    }

    private func mapError(_ error: Error) -> String {
        let nsError = error as NSError
        return "[\(nsError.domain) code=\(nsError.code)] \(nsError.localizedDescription)"
    }
}

#Preview {
    SetupPage(hasCompletedOnboarding: .constant(false), currentPage: .constant(2))
        .environment(SubscriptionManager())
        .preferredColorScheme(.dark)
}
