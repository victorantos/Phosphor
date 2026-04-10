import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PlanOption = .monthly

    enum PlanOption {
        case monthly, yearly
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    features
                    planPicker
                    legalText
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            actionButtons
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .safeAreaPadding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if subscriptionManager.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .alert("Error", isPresented: .init(
            get: { subscriptionManager.purchaseError != nil },
            set: { if !$0 { subscriptionManager.purchaseError = nil } }
        )) {
            Button("OK") { subscriptionManager.purchaseError = nil }
        } message: {
            Text(subscriptionManager.purchaseError ?? "")
        }
        .task {
            await subscriptionManager.loadProducts()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
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
        }
        .padding(.top, 8)
    }

    // MARK: - Features

    private var features: some View {
        VStack(alignment: .leading, spacing: 14) {
            FeatureItem(icon: "eye.slash.fill", color: .blue, text: "Block ads & trackers across all apps")
            FeatureItem(icon: "shield.lefthalf.filled", color: PhosphorTheme.accent, text: "Malware & adult content filtering")
            FeatureItem(icon: "lock.shield.fill", color: .purple, text: "Zero-knowledge privacy — encrypted PIR queries")
            FeatureItem(icon: "list.bullet.rectangle.fill", color: .orange, text: "Custom filter lists & manual entries")
            FeatureItem(icon: "chart.bar.fill", color: .green, text: "Real-time blocking dashboard")
            FeatureItem(icon: "arrow.clockwise", color: .secondary, text: "Automatic daily list updates")
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        VStack(spacing: 12) {
            if let monthly = subscriptionManager.monthlyProduct {
                PlanCard(
                    title: "Monthly",
                    price: monthly.displayPrice,
                    period: "/month",
                    badge: nil,
                    isSelected: selectedPlan == .monthly
                ) {
                    selectedPlan = .monthly
                }
            }

            if let yearly = subscriptionManager.yearlyProduct {
                let monthlyCost = yearly.price / 12
                let savings = "Save ~30%"
                PlanCard(
                    title: "Yearly",
                    price: yearly.displayPrice,
                    period: "/year",
                    badge: savings,
                    isSelected: selectedPlan == .yearly
                ) {
                    selectedPlan = .yearly
                }
            }
        }
    }

    // MARK: - Legal

    private var legalText: some View {
        VStack(spacing: 8) {
            Text("7-day free trial, then auto-renews. Cancel anytime in Settings > Subscriptions.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://nestclaw.com/phosphor/privacy")!)
                    .font(.caption)
                Link("Terms of Service", destination: URL(string: "https://nestclaw.com/phosphor/terms")!)
                    .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    let product: Product? = selectedPlan == .yearly
                        ? subscriptionManager.yearlyProduct
                        : subscriptionManager.monthlyProduct
                    guard let product else { return }
                    await subscriptionManager.purchase(product)
                    if subscriptionManager.isSubscribed {
                        dismiss()
                    }
                }
            } label: {
                Text("Start 7-Day Free Trial")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PhosphorTheme.accent)
            .controlSize(.large)

            Button {
                Task {
                    await subscriptionManager.restorePurchases()
                    if subscriptionManager.isSubscribed {
                        dismiss()
                    }
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
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

// MARK: - Plan Card

private struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PhosphorTheme.accent.opacity(0.2), in: Capsule())
                                .foregroundStyle(PhosphorTheme.accent)
                        }
                    }
                    Text("\(price)\(period)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? PhosphorTheme.accent : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? PhosphorTheme.accent : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
}
