import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(currentPage: $currentPage)
                .tag(0)

            PrivacyPage(currentPage: $currentPage)
                .tag(1)

            SetupPage(hasCompletedOnboarding: $hasCompletedOnboarding)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) {
            pageIndicator
                .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index == currentPage ? PhosphorTheme.accent : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .accessibilityLabel("Page \(currentPage + 1) of 3")
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    @Binding var currentPage: Int

    var body: some View {
        OnboardingPageLayout(
            icon: "shield.checkered",
            iconColor: PhosphorTheme.accent,
            title: "Welcome to Phosphor",
            subtitle: "System-wide protection against ads, trackers, malware, and unwanted content — built on Apple's newest privacy technology."
        ) {
            VStack(spacing: 12) {
                FeatureRow(icon: "eye.slash", title: "Block Ads", detail: "Remove ads across Safari and every app")
                FeatureRow(icon: "shield.lefthalf.filled", title: "Stop Trackers", detail: "Prevent cross-site tracking and fingerprinting")
                FeatureRow(icon: "exclamationmark.shield", title: "Block Malware", detail: "Protection from known malicious domains")
                FeatureRow(icon: "bolt.shield", title: "Fast & Efficient", detail: "On-device Bloom filter means zero latency for most URLs")
            }
        } action: {
            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PhosphorTheme.accent)
            .controlSize(.large)
        }
    }
}

// MARK: - Page 2: Privacy

private struct PrivacyPage: View {
    @Binding var currentPage: Int

    var body: some View {
        OnboardingPageLayout(
            icon: "lock.shield",
            iconColor: .blue,
            title: "Privacy by Design",
            subtitle: "Phosphor uses Apple's Private Information Retrieval (PIR) with homomorphic encryption. Here's what that means for you:"
        ) {
            VStack(spacing: 16) {
                PrivacyCard(
                    icon: "eye.slash.circle.fill",
                    title: "We Never See Your URLs",
                    detail: "The system checks URLs locally with a Bloom filter. For potential matches, encrypted queries go through Apple's relay — we can't see what you're browsing."
                )
                PrivacyCard(
                    icon: "server.rack",
                    title: "Zero Telemetry",
                    detail: "No analytics SDKs. No crash reporters that phone home. Your data stays on your device."
                )
                PrivacyCard(
                    icon: "network.badge.shield.half.filled",
                    title: "Apple's OHTTP Relay",
                    detail: "Even our server can't see your IP address. Apple's Oblivious HTTP relay adds a layer of network anonymity."
                )
            }
        } action: {
            Button {
                withAnimation { currentPage = 2 }
            } label: {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PhosphorTheme.accent)
            .controlSize(.large)
        }
    }
}

// MARK: - Supporting Views

private struct OnboardingPageLayout<Content: View, Action: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    @ViewBuilder let action: Action

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)

                content
                    .padding(.horizontal)

                Spacer(minLength: 20)

                action
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(PhosphorTheme.accent)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct PrivacyCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
