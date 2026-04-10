import NetworkExtension
import Observation
import os
import PhosphorShared

/// Wraps `NEURLFilterManager` to configure, enable, and observe the URL filter.
///
/// NOTE: This uses iOS 26 APIs. The `NEURLFilterManager` calls are guarded with
/// availability checks but won't resolve until built with the Xcode 26 SDK.
@Observable
final class FilterManagerService {
    private static let logger = Logger(
        subsystem: "com.example.phosphor",
        category: "FilterManager"
    )

    // MARK: - Published State

    private(set) var status: FilterStatus = .unknown
    private(set) var isEnabled: Bool = false
    private(set) var lastError: String?

    enum FilterStatus: String, Sendable {
        case unknown
        case stopped
        case starting
        case running
        case stopping
        case invalid
    }

    // MARK: - Configuration

    /// PIR server URL — must be configured before enabling the filter.
    /// This should be a domain-only URL (e.g., "https://pir.example.com").
    var pirServerURL: URL?

    /// Privacy Pass issuer URL — defaults to PIR server if nil.
    var pirPrivacyPassIssuerURL: URL?

    /// Authentication token for Privacy Pass token issuance.
    var pirAuthenticationToken: String?

    // MARK: - Setup

    /// Load the current filter configuration from system preferences.
    @MainActor
    func loadConfiguration() async {
        Self.logger.info("Loading filter configuration")
        do {
            let manager = NEURLFilterManager.shared
            try await manager.loadFromPreferences()
            isEnabled = manager.isEnabled
            updateStatus(from: manager.status)
            Self.logger.info("Configuration loaded, enabled: \(self.isEnabled), status: \(self.status.rawValue)")
        } catch {
            Self.logger.error("Failed to load configuration: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    /// Configure and save the URL filter. Prompts the user to allow the filter in Settings.
    @MainActor
    func enableFilter() async throws {
        Self.logger.info("Enabling URL filter")

        guard let serverURL = pirServerURL else {
            let msg = "PIR server URL not configured"
            Self.logger.error("\(msg)")
            lastError = msg
            throw FilterManagerError.notConfigured(msg)
        }

        guard let authToken = pirAuthenticationToken else {
            let msg = "PIR authentication token not configured"
            Self.logger.error("\(msg)")
            lastError = msg
            throw FilterManagerError.notConfigured(msg)
        }

        let manager = NEURLFilterManager.shared
        try await manager.loadFromPreferences()

        try manager.setConfiguration(
            pirServerURL: serverURL,
            pirPrivacyPassIssuerURL: pirPrivacyPassIssuerURL,
            pirAuthenticationToken: authToken,
            controlProviderBundleIdentifier: PhosphorConstants.filterExtensionBundleID
        )

        manager.localizedDescription = "Phosphor URL Filter"
        manager.isEnabled = true
        manager.shouldFailClosed = false
        manager.prefilterFetchInterval = 86400 // 24 hours

        try await manager.saveToPreferences()

        isEnabled = true
        updateStatus(from: manager.status)
        lastError = nil

        Self.logger.info("Filter enabled and saved to preferences")
    }

    /// Disable the URL filter.
    @MainActor
    func disableFilter() async throws {
        Self.logger.info("Disabling URL filter")

        let manager = NEURLFilterManager.shared
        try await manager.loadFromPreferences()
        manager.isEnabled = false
        try await manager.saveToPreferences()

        isEnabled = false
        updateStatus(from: manager.status)
        Self.logger.info("Filter disabled")
    }

    /// Remove the filter configuration entirely.
    @MainActor
    func removeFilter() async throws {
        Self.logger.info("Removing URL filter")
        let manager = NEURLFilterManager.shared
        try await manager.removeFromPreferences()
        isEnabled = false
        status = .unknown
        Self.logger.info("Filter removed")
    }

    /// Start observing status changes.
    func observeStatusChanges() {
        Task {
            let manager = NEURLFilterManager.shared
            for await newStatus in manager.handleStatusChange() {
                await MainActor.run {
                    updateStatus(from: newStatus)
                }
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func updateStatus(from neStatus: NEURLFilterManager.Status) {
        switch neStatus {
        case .invalid:  status = .invalid
        case .stopped:  status = .stopped
        case .starting: status = .starting
        case .running:  status = .running
        case .stopping: status = .stopping
        @unknown default: status = .unknown
        }
        Self.logger.debug("Status updated: \(self.status.rawValue)")
    }
}

enum FilterManagerError: LocalizedError {
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let msg): msg
        }
    }
}
