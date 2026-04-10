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
        var foundActive = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if Self.productIDs.contains(transaction.productID) {
                foundActive = true
                activeProductID = transaction.productID
                break
            }
        }

        isSubscribed = foundActive
        if !foundActive {
            activeProductID = nil
        }

        Self.logger.info("Subscription status: \(self.isSubscribed ? "active" : "inactive")")
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
