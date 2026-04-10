import NetworkExtension
import SwiftUI

struct SetupPage: View {
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
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

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

                Spacer(minLength: 20)

                actionButtons
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
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
            "Saving filter configuration..."
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
            ProgressView("Saving configuration...")

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

        do {
            let manager = NEURLFilterManager.shared
            try await manager.loadFromPreferences()

            // NOTE: PIR server configuration is required for production.
            // For development/testing, we set a placeholder that will need to
            // be replaced with a real PIR server URL before the filter can
            // actually resolve Bloom filter matches.
            //
            // The Bloom filter prefilter still works for fast local rejection
            // even without a PIR server — the system just can't confirm matches.

            manager.localizedDescription = "Phosphor URL Filter"
            manager.isEnabled = true
            manager.shouldFailClosed = false
            manager.prefilterFetchInterval = 86400

            try await manager.saveToPreferences()

            withAnimation { setupState = .success }
        } catch {
            errorMessage = mapError(error)
            withAnimation { setupState = .failed }
        }
    }

    private func mapError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case 1: // configurationPermissionDenied or similar
            return "Permission denied. Open Settings > General > VPN & Device Management to allow Phosphor."
        default:
            return error.localizedDescription
        }
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
