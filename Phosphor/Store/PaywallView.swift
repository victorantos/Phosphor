import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    /// Looked up by product ID: the group ID in App Store Connect is not the
    /// one in the local StoreKit file, so a group lookup only works in Xcode.
    /// The store view lists plans in this order, so annual comes first.
    private let productIDs = [SubscriptionManager.yearlyID, SubscriptionManager.monthlyID]
    private let privacyPolicyURL = URL(string: "https://phosphor.online/privacy")!
    private let termsOfServiceURL = URL(string: "https://phosphor.online/terms")!

    var body: some View {
        NavigationStack {
            // StoreKit's own store view stays in charge of the plan picker,
            // purchase, restore and the policy buttons — App Review checks those.
            // Only the marketing content above it is ours to design.
            SubscriptionStoreView(productIDs: productIDs) {
                marketingContent
            }
            // Both plans sit in the bottom bar next to the purchase button, so they are
            // visible without scrolling past the marketing copy and terms.
            .subscriptionStoreControlStyle(.compactPicker, placement: .bottomBar)
            .subscriptionStorePickerItemBackground(PhosphorTheme.ink900)
            .storeButton(.visible, for: .restorePurchases)
            .storeButton(.visible, for: .policies)
            .storeButton(.hidden, for: .cancellation)
            .subscriptionStorePolicyDestination(url: privacyPolicyURL, for: .privacyPolicy)
            .subscriptionStorePolicyDestination(url: termsOfServiceURL, for: .termsOfService)
            .background(paywallBackdrop)
            .tint(PhosphorTheme.phosphor)
            .onInAppPurchaseCompletion { _, result in
                switch result {
                case .success(.success):
                    Task {
                        await subscriptionManager.updateSubscriptionStatus()
                        // The trial reminder needs permission to notify.
                        await SubscriptionReminders.requestAuthorization()
                        await SubscriptionGate.run()
                        dismiss()
                    }
                default:
                    break
                }
            }
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
            .task {
                if subscriptionManager.products.isEmpty {
                    await subscriptionManager.loadProducts()
                }
            }
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
            .padding(.bottom, 20)

            subscriptionTerms
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Subscription Terms & Legal Links

    private var legalLinks: AttributedString {
        var terms = AttributedString("Terms of Use (EULA)")
        terms.link = termsOfServiceURL
        var privacy = AttributedString("Privacy Policy")
        privacy.link = privacyPolicyURL
        return terms + AttributedString(" · ") + privacy
    }

    /// Prices come from the App Store so they match the user's storefront.
    private var termsText: String {
        var plans = "Choose Annual or Monthly."
        if let yearly = subscriptionManager.yearlyProduct, let monthly = subscriptionManager.monthlyProduct {
            plans = "Choose Annual (\(yearly.displayPrice) a year) or Monthly (\(monthly.displayPrice) a month)."
        }
        return "Phosphor Premium is an auto-renewing subscription and is required for filtering. \(plans) New subscribers get a 7-day free trial; payment is charged to your Apple ID when the trial ends, or at confirmation if you are not eligible for a trial. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel any time in Settings › Apple Account › Subscriptions."
    }

    private var subscriptionTerms: some View {
        VStack(spacing: 10) {
            Text(termsText)
                .font(.system(size: 12))
                .foregroundStyle(PhosphorTheme.ink400)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Inline links: a Link here would be drawn as a large button by the store view.
            Text(legalLinks)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PhosphorTheme.ink400)
                .tint(PhosphorTheme.phosphor)
        }
        .padding(.top, 4)
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
