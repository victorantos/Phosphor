import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    /// Looked up by product ID: the subscription group's identifier is assigned by
    /// App Store Connect and differs from the one in the local StoreKit file.
    private let productIDs = [SubscriptionManager.monthlyID, SubscriptionManager.yearlyID]
    private let privacyPolicyURL = URL(string: "https://phosphor.online/privacy")!
    private let termsOfServiceURL = URL(string: "https://phosphor.online/terms")!

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(productIDs: productIDs) {
                marketingContent
            }
            .subscriptionStorePickerItemBackground(.thinMaterial)
            .storeButton(.visible, for: .restorePurchases)
            .storeButton(.visible, for: .policies)
            .subscriptionStorePolicyDestination(url: privacyPolicyURL, for: .privacyPolicy)
            .subscriptionStorePolicyDestination(url: termsOfServiceURL, for: .termsOfService)
            .onInAppPurchaseCompletion { _, result in
                switch result {
                case .success(.success):
                    Task {
                        await subscriptionManager.updateSubscriptionStatus()
                        dismiss()
                    }
                default:
                    break
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Marketing Content

    private var marketingContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 56))
                .foregroundStyle(PhosphorTheme.accent)

            Text("Phosphor Premium")
                .font(.title)
                .fontWeight(.bold)

            Text("System-wide URL filtering powered by Apple's Private Information Retrieval. We never see the URLs you visit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                FeatureItem(icon: "eye.slash.fill", color: .blue, text: "Block ads & trackers across all apps")
                FeatureItem(icon: "shield.lefthalf.filled", color: PhosphorTheme.accent, text: "Malware & adult content filtering")
                FeatureItem(icon: "lock.shield.fill", color: .purple, text: "Zero-knowledge privacy — encrypted PIR queries")
                FeatureItem(icon: "list.bullet.rectangle.fill", color: .orange, text: "Custom filter lists & manual entries")
                FeatureItem(icon: "chart.bar.fill", color: .green, text: "Real-time blocking dashboard")
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            subscriptionTerms
        }
        .padding(.top, 8)
    }

    // MARK: - Subscription Terms & Legal Links

    private var subscriptionTerms: some View {
        VStack(spacing: 10) {
            Text("Phosphor Premium is an auto-renewing subscription. Choose Monthly ($29.99/month) or Yearly ($249.99/year). Each plan includes a 1-week free trial. Payment is charged to your Apple ID at confirmation. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link("Terms of Use (EULA)", destination: termsOfServiceURL)
                Text("·").foregroundStyle(.secondary)
                Link("Privacy Policy", destination: privacyPolicyURL)
            }
            .font(.caption2)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

// MARK: - Feature Item

private struct FeatureItem: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
}
