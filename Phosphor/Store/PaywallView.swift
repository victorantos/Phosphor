import os
import StoreKit
import SwiftUI

/// Our own paywall rather than StoreKit's `SubscriptionStoreView`: the store view
/// cannot preselect a plan, and it adds its own policy links wherever it likes. App
/// Review needs the plan name, length and price next to the purchase button, the
/// auto-renewal terms, Restore, and working links to the terms and privacy policy;
/// all of them are here.
struct PaywallView: View {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "Paywall")

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase

    @State private var selectedID = SubscriptionManager.yearlyID
    @State private var trialEligible: [String: Bool] = [:]
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private let privacyPolicyURL = URL(string: "https://phosphor.online/privacy")!
    private let termsOfServiceURL = URL(string: "https://phosphor.online/terms")!

    private var yearly: Product? { subscriptionManager.yearlyProduct }
    private var monthly: Product? { subscriptionManager.monthlyProduct }
    private var selected: Product? { selectedID == SubscriptionManager.yearlyID ? yearly : monthly }

    var body: some View {
        NavigationStack {
            ScrollView {
                marketingContent
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                purchasePanel
            }
            .background(paywallBackdrop)
            .tint(PhosphorTheme.phosphor)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PhosphorTheme.ink300)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(PhosphorTheme.fill))
                    }
                    .accessibilityLabel("Close")
                }
            }
            .toolbarBackground(PhosphorTheme.ink950, for: .navigationBar)
            .task { await load() }
        }
    }

    private func load() async {
        if subscriptionManager.products.isEmpty {
            await subscriptionManager.loadProducts()
        }
        for product in subscriptionManager.products {
            trialEligible[product.id] = await product.subscription?.isEligibleForIntroOffer ?? false
        }
    }

    /// Warm black with a single bloom behind the mark — the light is the subject.
    private var paywallBackdrop: some View {
        PhosphorTheme.ink950
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [PhosphorTheme.phosphor.opacity(0.16), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
    }

    // MARK: - Marketing Content

    private var marketingContent: some View {
        VStack(spacing: 0) {
            PhosphorMark(size: 48)
                .padding(.bottom, 12)

            Text("PHOSPHOR PREMIUM")
                .font(PhosphorTheme.eyebrow)
                .tracking(1.0)
                .foregroundStyle(PhosphorTheme.phosphor)
                .padding(.bottom, 12)

            Text("Turn filtering on. Keep your history yours.")
                .font(.system(size: 26, weight: .bold))
                .kerning(-0.9)
                .foregroundStyle(PhosphorTheme.ink50)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 10) {
                FeatureItem(text: "Block ads & trackers across all apps")
                FeatureItem(text: "Malware & adult content filtering")
                FeatureItem(text: "Zero-knowledge privacy — encrypted PIR queries")
                FeatureItem(text: "Custom filter lists & manual entries")
                FeatureItem(text: "A reminder 2 days before your free trial ends")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Purchase Panel

    private var purchasePanel: some View {
        VStack(spacing: 12) {
            if let yearly, let monthly {
                HStack(spacing: 10) {
                    PlanCard(
                        title: "Yearly",
                        price: "\(yearly.displayPrice)/year",
                        detail: "\(Self.perMonth(yearly)) a month",
                        badge: Self.savings(yearly: yearly, monthly: monthly).map { "Save \($0)%" },
                        isSelected: selectedID == yearly.id
                    ) { selectedID = yearly.id }

                    PlanCard(
                        title: "Monthly",
                        price: "\(monthly.displayPrice)/month",
                        detail: "Billed monthly",
                        badge: nil,
                        isSelected: selectedID == monthly.id
                    ) { selectedID = monthly.id }
                }
            } else if subscriptionManager.purchaseError != nil {
                VStack(spacing: 8) {
                    Text("Plans could not be loaded.")
                        .font(.system(size: 15))
                        .foregroundStyle(PhosphorTheme.ink300)
                    Button("Try again") { Task { await load() } }
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(height: 96)
            } else {
                ProgressView()
                    .tint(PhosphorTheme.ink300)
                    .frame(height: 96)
            }

            if let selected {
                Text(offerLine(for: selected))
                    .font(.system(size: 14))
                    .foregroundStyle(PhosphorTheme.ink300)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(PhosphorTheme.signalRed)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await buy() }
            } label: {
                if isPurchasing {
                    ProgressView().tint(PhosphorTheme.ink950)
                } else {
                    Text(isTrialAvailable ? "Start free trial" : "Subscribe")
                }
            }
            .buttonStyle(PhosphorPrimaryButtonStyle())
            .disabled(selected == nil || isPurchasing || isRestoring)

            linksRow

            Text(termsText)
                .font(.system(size: 11))
                .foregroundStyle(PhosphorTheme.ink400)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background {
            PhosphorTheme.ink950
                .overlay(alignment: .top) {
                    Rectangle().fill(PhosphorTheme.line).frame(height: 1)
                }
                .ignoresSafeArea()
        }
    }

    private var linksRow: some View {
        HStack(spacing: 6) {
            Button(isRestoring ? "Restoring…" : "Restore") {
                Task { await restore() }
            }
            .disabled(isPurchasing || isRestoring)
            Text("·").foregroundStyle(PhosphorTheme.ink600)
            Link("Terms of Use (EULA)", destination: termsOfServiceURL)
            Text("·").foregroundStyle(PhosphorTheme.ink600)
            Link("Privacy Policy", destination: privacyPolicyURL)
        }
        .font(.system(size: 12, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(PhosphorTheme.phosphor)
    }

    // MARK: - Copy

    private var isTrialAvailable: Bool {
        guard let selected else { return false }
        return trialEligible[selected.id] == true && selected.subscription?.introductoryOffer != nil
    }

    private func offerLine(for product: Product) -> String {
        let price = Self.priceWithPeriod(product)
        if isTrialAvailable, let trial = product.subscription?.introductoryOffer {
            return "\(Self.describe(trial.period)) free, then \(price). Cancel anytime."
        }
        return "\(price). Cancel anytime."
    }

    /// The auto-renewal terms App Review asks for, for the selected plan.
    private var termsText: String {
        let renewal = selected.map { "\(Self.priceWithPeriod($0)) " } ?? ""
        let charge = isTrialAvailable ? "when the free trial ends" : "at confirmation of purchase"
        return "Phosphor Premium is required for filtering. Payment of \(renewal)is charged to your Apple ID \(charge). The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple Account › Subscriptions."
    }

    private static func priceWithPeriod(_ product: Product) -> String {
        switch product.subscription?.subscriptionPeriod.unit {
        case .year: "\(product.displayPrice)/year"
        case .month: "\(product.displayPrice)/month"
        default: product.displayPrice
        }
    }

    private static func describe(_ period: Product.SubscriptionPeriod) -> String {
        switch (period.unit, period.value) {
        case (.week, 1): "7 days"
        case (.day, let n): "\(n) days"
        case (.week, let n): "\(n) weeks"
        case (.month, 1): "1 month"
        case (.month, let n): "\(n) months"
        default: "Free trial,"
        }
    }

    private static func perMonth(_ yearly: Product) -> String {
        (yearly.price / 12).formatted(yearly.priceFormatStyle)
    }

    /// Whole-percent saving of the yearly plan against twelve monthly payments.
    private static func savings(yearly: Product, monthly: Product) -> Int? {
        let twelveMonths = monthly.price * 12
        guard twelveMonths > 0 else { return nil }
        let fraction = 1 - NSDecimalNumber(decimal: yearly.price / twelveMonths).doubleValue
        let percent = Int(fraction * 100)
        return percent > 0 ? percent : nil
    }

    // MARK: - Actions

    private func buy() async {
        guard let selected else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            switch try await purchase(selected) {
            case .success(.verified(let transaction)):
                Self.logger.notice("Purchase returned transaction \(transaction.id) for \(transaction.productID, privacy: .public), expires \(transaction.expirationDate?.description ?? "never", privacy: .public), revoked: \(transaction.revocationDate != nil)")
                await transaction.finish()
                await subscriptionManager.updateSubscriptionStatus()
                // StoreKit can report success with a transaction that grants nothing,
                // such as an earlier refunded one. Only close once access is real.
                guard subscriptionManager.isSubscribed else {
                    errorMessage = "The purchase did not complete. Please try again, or use Restore."
                    return
                }
                // The trial reminder needs permission to notify.
                await SubscriptionReminders.requestAuthorization()
                await SubscriptionGate.run()
                dismiss()
            case .success(.unverified(_, let error)):
                Self.logger.error("Purchase unverified: \(error.localizedDescription, privacy: .public)")
                errorMessage = "The purchase could not be verified. Try Restore."
            case .pending:
                errorMessage = "The purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            Self.logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "The purchase did not go through. Please try again."
        }
    }

    private func restore() async {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }
        await subscriptionManager.restorePurchases()
        if subscriptionManager.isSubscribed {
            await SubscriptionGate.run()
            dismiss()
        } else {
            errorMessage = "No active subscription was found for this Apple Account."
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let title: String
    let price: String
    let detail: String
    let badge: String?
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? PhosphorTheme.phosphor : PhosphorTheme.ink300)
                    Spacer(minLength: 4)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PhosphorTheme.ink950)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(PhosphorTheme.phosphor))
                    }
                }
                Text(price)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(PhosphorTheme.ink50)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(PhosphorTheme.ink400)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                    .fill(isSelected ? PhosphorTheme.phosphorTint : PhosphorTheme.ink900)
            }
            .overlay {
                RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                    .strokeBorder(isSelected ? PhosphorTheme.phosphor : PhosphorTheme.lineStrong,
                                  lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .animation(PhosphorTheme.controlAnimation, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Feature Item

private struct FeatureItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PhosphorTheme.phosphor)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(PhosphorTheme.ink300)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
        .preferredColorScheme(.dark)
}
