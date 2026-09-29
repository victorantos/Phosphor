import Foundation
import NetworkExtension
import os
import PhosphorShared

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
            manager.isEnabled = true
            try await manager.saveToPreferences()
            logger.info("Restarted the filter to load the new prefilter")
        } catch {
            logger.error("Restarting the filter failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
