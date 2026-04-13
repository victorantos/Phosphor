import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    private let groupID = "phosphor_premium"

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(groupID: groupID) {
                marketingContent
            }
            .subscriptionStorePickerItemBackground(.thinMaterial)
            .storeButton(.visible, for: .restorePurchases)
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
        }
        .padding(.top, 8)
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
