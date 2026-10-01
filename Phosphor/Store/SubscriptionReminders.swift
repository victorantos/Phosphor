import Foundation
import os
import StoreKit
import UserNotifications

/// Local notifications ahead of a trial or subscription ending, so the user is never
/// charged by surprise and protection never stops without warning.
@MainActor
enum SubscriptionReminders {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "Reminders")

    private static let endingID = "subscription-ending"
    private static let pausedID = "protection-paused"

    /// How long before the end of a trial or subscription the first reminder comes.
    private static let leadTime: TimeInterval = 2 * 86400

    private static var center: UNUserNotificationCenter { .current() }

    /// Asked right after a purchase, when the reminder it enables makes sense.
    static func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            logger.info("Notifications \(granted ? "allowed" : "declined")")
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Replaces the scheduled reminders to match the current subscription.
    static func update(for entitlement: Transaction?) async {
        center.removePendingNotificationRequests(withIdentifiers: [endingID, pausedID])
        guard let entitlement, let expiration = entitlement.expirationDate else { return }

        let isTrial = entitlement.offer?.type == .introductory
            && entitlement.offer?.paymentMode == .freeTrial
        let willRenew = await willAutoRenew(entitlement)
        let endDate = expiration.formatted(date: .abbreviated, time: .omitted)

        if willRenew {
            // A paid subscription that renews needs no reminder; a trial about to turn
            // into a charge does.
            guard isTrial else { return }
            let price = await priceText(for: entitlement.productID)
            await schedule(
                endingID,
                at: expiration.addingTimeInterval(-leadTime),
                title: "Your free trial ends in 2 days",
                body: "Phosphor Premium then renews at \(price) on \(endDate). To avoid being charged, cancel before then in Settings › Apple Account › Subscriptions."
            )
        } else {
            await schedule(
                endingID,
                at: expiration.addingTimeInterval(-leadTime),
                title: isTrial ? "Your free trial ends in 2 days" : "Phosphor Premium ends in 2 days",
                body: "Filtering pauses on \(endDate). Renew in Phosphor to keep protection on."
            )
            await schedule(
                pausedID,
                at: expiration,
                title: "Protection paused",
                body: "Phosphor Premium has ended, so filtering is paused. Open Phosphor to renew and resume."
            )
        }
    }

    /// Sent when the app finds access gone and switches the filter off.
    static func notifyPaused() async {
        await schedule(
            pausedID,
            at: nil,
            title: "Protection paused",
            body: "Filtering is paused because Phosphor Premium is not active. Open Phosphor to resume."
        )
    }

    // MARK: - Helpers

    private static func willAutoRenew(_ transaction: Transaction) async -> Bool {
        guard let status = await transaction.subscriptionStatus,
              case .verified(let renewal) = status.renewalInfo
        else { return true }
        return renewal.willAutoRenew
    }

    private static func priceText(for productID: String) async -> String {
        guard let product = try? await Product.products(for: [productID]).first else {
            return "the regular price"
        }
        switch product.subscription?.subscriptionPeriod.unit {
        case .year: return "\(product.displayPrice) a year"
        case .month: return "\(product.displayPrice) a month"
        default: return product.displayPrice
        }
    }

    /// Schedules a notification for `date`, or delivers it now when `date` is nil.
    /// Dates already past are skipped.
    private static func schedule(_ id: String, at date: Date?, title: String, body: String) async {
        let trigger: UNNotificationTrigger?
        if let date {
            let interval = date.timeIntervalSinceNow
            guard interval > 1 else { return }
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        } else {
            trigger = nil
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        } catch {
            logger.error("Scheduling \(id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
