import Observation
import os
import StoreKit

@Observable
@MainActor
final class SubscriptionManager {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "Subscriptions")

    // MARK: - Product IDs

    static let monthlyID = "com.nestclaw.phosphor.monthly"
    static let yearlyID = "com.nestclaw.phosphor.yearly"
    private static let productIDs: Set<String> = [monthlyID, yearlyID]

    // MARK: - State

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var currentSubscription: Product.SubscriptionInfo.Status?
    var purchaseError: String?
    private(set) var isLoading = false

    /// The active product the user is subscribed to, if any.
    private(set) var activeProductID: String?

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyID } }

    // MARK: - Lifecycle

    private nonisolated(unsafe) var transactionTask: Task<Void, Never>?

    init() {
        transactionTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit {
        transactionTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
            Self.logger.info("Loaded \(self.products.count) products")
            await updateSubscriptionStatus()
        } catch {
            Self.logger.error("Failed to load products: \(error.localizedDescription)")
            purchaseError = "Unable to load subscription options."
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                Self.logger.info("Purchase successful: \(product.id)")

            case .userCancelled:
                Self.logger.info("User cancelled purchase")

            case .pending:
                Self.logger.info("Purchase pending (ask to buy)")
                purchaseError = "Purchase is pending approval."

            @unknown default:
                Self.logger.warning("Unknown purchase result")
            }
        } catch {
            Self.logger.error("Purchase failed: \(error.localizedDescription)")
            purchaseError = "Purchase failed. Please try again."
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            Self.logger.info("Purchases restored, subscribed: \(self.isSubscribed)")
        } catch {
            Self.logger.error("Restore failed: \(error.localizedDescription)")
            purchaseError = "Unable to restore purchases."
        }
    }

    // MARK: - Subscription Status

    func updateSubscriptionStatus() async {
        let entitlement = await Self.currentEntitlement()
        activeProductID = entitlement?.productID
        isSubscribed = entitlement != nil || Self.assumesSubscribed

        Self.logger.info("Subscription status: \(self.isSubscribed ? "active" : "inactive")")
    }

    /// The transaction that gives access to Premium right now, a free trial included.
    /// Nil once a subscription has expired or been refunded.
    static func currentEntitlement() async -> Transaction? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil
            else { continue }
            return transaction
        }
        return nil
    }

    /// Whether Premium is active, for code that runs without the app's UI.
    static func hasAccess() async -> Bool {
        await currentEntitlement() != nil || assumesSubscribed
    }

    // MARK: - Development

    /// Development builds started outside Xcode cannot buy anything: there is no
    /// StoreKit configuration file, and the sandbox only sells once the Paid Apps
    /// Agreement is active. Launching with `PHOSPHOR_ASSUME_SUBSCRIBED=1` treats the app
    /// as subscribed until it is launched with `PHOSPHOR_ASSUME_SUBSCRIBED=0`.
    /// Release builds ignore it.
    static var assumesSubscribed: Bool {
        #if DEBUG
        let key = "debugAssumeSubscribed"
        switch ProcessInfo.processInfo.environment["PHOSPHOR_ASSUME_SUBSCRIBED"] {
        case "1": UserDefaults.standard.set(true, forKey: key)
        case "0": UserDefaults.standard.removeObject(forKey: key)
        default: break
        }
        return UserDefaults.standard.bool(forKey: key)
        #else
        return false
        #endif
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }
            await transaction.finish()
            await updateSubscriptionStatus()
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
