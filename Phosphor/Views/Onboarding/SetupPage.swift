import NetworkExtension
import os
import PhosphorShared
import SwiftUI

struct SetupPage: View {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "Setup")

    /// How long to wait for the filter to report that it is running.
    private static let startTimeoutSeconds = 90

    @Binding var hasCompletedOnboarding: Bool
    @State private var setupState: SetupState = .ready
    @State private var errorMessage: String?

    enum SetupState {
        case ready
        case enabling
        case success
        case failed
        case skipped
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            statusIcon

            VStack(spacing: 8) {
                Text(titleText)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(subtitleText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)

            if let error = errorMessage {
                errorCard(error)
            }

            stepsCard

            Spacer()

            PageDots(currentPage: 2)

            actionButtons
                .padding(.horizontal, 24)
                .safeAreaPadding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Dynamic Content

    private var titleText: String {
        switch setupState {
        case .ready, .failed: "Enable URL Filtering"
        case .enabling: "Enabling..."
        case .success: "You're Protected"
        case .skipped: "Setup Later"
        }
    }

    private var subtitleText: String {
        switch setupState {
        case .ready:
            "Phosphor needs your permission to enable system-wide URL filtering. iOS will ask you to confirm in Settings."
        case .enabling:
            "Starting the filter. The first time can take up to a minute."
        case .success:
            "Phosphor is now filtering URLs across your device. You can manage filter lists from the Lists tab."
        case .failed:
            "Something went wrong. You can try again or set up filtering later in Settings."
        case .skipped:
            "You can enable filtering at any time from the Settings tab."
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch setupState {
        case .ready:
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 64))
                .foregroundStyle(PhosphorTheme.accent)
        case .enabling:
            ProgressView()
                .controlSize(.extraLarge)
        case .success:
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
        case .skipped:
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            StepRow(number: 1, text: "Phosphor saves a filter configuration", done: setupState == .success)
            StepRow(number: 2, text: "iOS prompts you to allow the URL filter", done: setupState == .success)
            StepRow(number: 3, text: "URLs are filtered across Safari and all apps", done: setupState == .success)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Error

    private func errorCard(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        switch setupState {
        case .ready, .failed:
            VStack(spacing: 12) {
                Button {
                    Task { await enableFilter() }
                } label: {
                    Text("Enable Filtering")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PhosphorTheme.accent)
                .controlSize(.large)
                .disabled(setupState == .enabling)

                Button {
                    setupState = .skipped
                } label: {
                    Text("Skip for Now")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }

        case .enabling:
            ProgressView("Starting the filter...")

        case .success, .skipped:
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PhosphorTheme.accent)
            .controlSize(.large)
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

// MARK: - Step Row

private struct StepRow: View {
    let number: Int
    let text: String
    let done: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(number)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.secondary))
                }
            }
            .frame(width: 22)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(done ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)\(done ? ", completed" : "")")
    }
}

#Preview {
    SetupPage(hasCompletedOnboarding: .constant(false))
}
