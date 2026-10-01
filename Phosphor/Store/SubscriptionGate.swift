import BackgroundTasks
import Foundation
import NetworkExtension
import os
import PhosphorShared

/// Filtering is part of Phosphor Premium, a free trial included.
///
/// When the subscription or trial ends, the filter is switched off and the user is
/// told why, rather than having protection disappear silently. When they subscribe
/// again it is switched back on.
@MainActor
enum SubscriptionGate {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "SubscriptionGate")
    private static let pausedKey = "pausedForSubscription"

    /// Lets the system wake the app to check the subscription, so the filter also
    /// pauses for people who never open the app. Listed in Info.plist.
    nonisolated static let refreshTaskID = "com.nestclaw.phosphor.subscription-check"

    /// Whether filtering is off because the subscription or trial ended.
    static var isPausedForSubscription: Bool {
        PhosphorConstants.sharedDefaults?.bool(forKey: pausedKey) ?? false
    }

    private static func setPausedForSubscription(_ paused: Bool) {
        PhosphorConstants.sharedDefaults?.set(paused, forKey: pausedKey)
    }

    /// Switches the filter off without access and back on when access returns.
    /// Returns whether it paused the filter just now.
    @discardableResult
    static func reconcile(hasAccess: Bool) async -> Bool {
        let manager = NEURLFilterManager.shared
        do {
            try await manager.loadFromPreferences()
        } catch {
            logger.error("Loading the filter failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
        // Nothing to do before setup has saved a configuration.
        guard manager.pirServerURL != nil else { return false }

        do {
            if hasAccess {
                guard isPausedForSubscription else { return false }
                setPausedForSubscription(false)
                guard !FilterPause.isActive, !manager.isEnabled else { return false }
                manager.isEnabled = true
                try await manager.saveToPreferences()
                logger.notice("Subscription active again, filter resumed")
                return false
            }

            guard manager.isEnabled || FilterPause.isActive else { return false }
            // A pause running out would otherwise switch the filter back on.
            FilterPause.clear()
            setPausedForSubscription(true)
            if manager.isEnabled {
                manager.isEnabled = false
                try await manager.saveToPreferences()
            }
            logger.notice("No active subscription, filter paused")
            return true
        } catch {
            logger.error("Applying subscription state failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Asks the system to run the background check around the time access could end.
    static func scheduleRefresh(expiration: Date?) {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        let tomorrow = Date.now.addingTimeInterval(86400)
        if let expiration, expiration > .now {
            request.earliestBeginDate = min(expiration, tomorrow)
        } else {
            request.earliestBeginDate = tomorrow
        }
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Scheduling the subscription check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The whole check: filter state, reminders and the next background run. Call when
    /// the app becomes active, after a purchase, and from the background task.
    static func run() async {
        let entitlement = await SubscriptionManager.currentEntitlement()
        let hasAccess = entitlement != nil || SubscriptionManager.assumesSubscribed
        let paused = await reconcile(hasAccess: hasAccess)
        if paused {
            await SubscriptionReminders.notifyPaused()
        }
        await SubscriptionReminders.update(for: entitlement)
        scheduleRefresh(expiration: entitlement?.expirationDate)
    }
}
