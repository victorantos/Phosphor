import Foundation
import NetworkExtension
import os
import PhosphorShared
import UIKit

/// Makes the system filter follow changes to the lists.
///
/// The system reads the prefilter when the filter starts and then only once per
/// `prefilterFetchInterval`, so a rebuilt prefilter would otherwise go unused for up to
/// a day. Restarting the filter makes the system fetch it straight away.
@MainActor
enum FilterRefresher {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "FilterRefresher")
    private static var pending: Task<Void, Never>?

    /// Call after the lists or their rules change. Changes made in quick succession,
    /// such as switching several lists, lead to a single restart.
    static func listsChanged() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await apply()
        }
    }

    private static func apply() async {
        // Filtering is off between the two saves. Without this the app can be suspended
        // in that gap, when the user switches to Safari to try the change, and
        // filtering stays off until the app is opened again.
        let background = UIApplication.shared.beginBackgroundTask(withName: "Restart URL filter")
        defer { UIApplication.shared.endBackgroundTask(background) }

        let previousTag = try? PrefilterStore().loadMetadata()?.tag
        let tag = await PrefilterStore.rebuildFromCurrentLists()?.tag
        guard tag != previousTag else { return }
        guard !FilterPause.isActive else { return }

        do {
            let manager = NEURLFilterManager.shared
            try await manager.loadFromPreferences()
            guard manager.isEnabled else { return }
            manager.isEnabled = false
            try await manager.saveToPreferences()

            // Switching straight back on is treated as no change and the filter keeps
            // running with the old prefilter, so give the system a moment to stop it.
            // A disabled filter reports `stopped` or `invalid`; the status also reads
            // `invalid` right after a save, hence the fixed wait before checking.
            try? await Task.sleep(for: .seconds(1))
            var status = await manager.status
            for _ in 0..<12 where status != .stopped && status != .invalid {
                try? await Task.sleep(for: .milliseconds(250))
                status = await manager.status
            }

            try await manager.loadFromPreferences()
            manager.isEnabled = true
            try await manager.saveToPreferences()
            logger.info("Restarted the filter to load the new prefilter, was \(String(describing: status), privacy: .public)")
        } catch {
            logger.error("Restarting the filter failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
