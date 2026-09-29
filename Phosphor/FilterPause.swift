import Foundation
import NetworkExtension
import os
import PhosphorShared

/// Pauses and resumes the system URL filter.
///
/// A pause switches the filter configuration off and remembers when it should
/// come back. iOS gives the app no way to run at that moment, so the filter is
/// switched back on the next time the app is opened after the pause has ended.
@MainActor
enum FilterPause {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "FilterPause")
    private static let endDateKey = "pauseEndDate"

    /// When the current pause ends, or nil when filtering is not paused.
    static var endDate: Date? {
        PhosphorConstants.sharedDefaults?.object(forKey: endDateKey) as? Date
    }

    static func pause(until end: Date) async throws {
        PhosphorConstants.sharedDefaults?.set(end, forKey: endDateKey)
        try await setFilterEnabled(false)
        logger.info("Filtering paused until \(end)")
    }

    /// Forgets any pause without touching the filter. Setup calls this because
    /// switching filtering on is a decision to stop pausing.
    static func clear() {
        PhosphorConstants.sharedDefaults?.removeObject(forKey: endDateKey)
    }

    static func resume() async throws {
        PhosphorConstants.sharedDefaults?.removeObject(forKey: endDateKey)
        try await setFilterEnabled(true)
        logger.info("Filtering resumed")
    }

    /// Whether a pause is in effect right now.
    static var isActive: Bool {
        guard let end = endDate else { return false }
        return end > .now
    }

    /// Brings the system filter in line with the stored pause: off while a pause is in
    /// effect, back on once it has run out. Call when the app becomes active.
    static func reconcile() async {
        guard let end = endDate else { return }
        do {
            if end > .now {
                try await setFilterEnabled(false)
            } else {
                try await resume()
            }
        } catch {
            logger.error("Applying pause state failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func setFilterEnabled(_ enabled: Bool) async throws {
        let manager = NEURLFilterManager.shared
        try await manager.loadFromPreferences()
        guard manager.isEnabled != enabled else { return }
        manager.isEnabled = enabled
        try await manager.saveToPreferences()
    }
}
