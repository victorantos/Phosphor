import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage: Int

    init(hasCompletedOnboarding: Binding<Bool>, initialPage: Int = 0) {
        _hasCompletedOnboarding = hasCompletedOnboarding
        _currentPage = State(initialValue: initialPage)
    }

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(currentPage: $currentPage).tag(0)
            PrivacyPage(currentPage: $currentPage).tag(1)
            SetupPage(hasCompletedOnboarding: $hasCompletedOnboarding, currentPage: $currentPage).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(PhosphorTheme.ink950.ignoresSafeArea())
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    @Binding var currentPage: Int
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var isRestoring = false

    var body: some View {
        OnboardingLayout {
            VStack(spacing: 0) {
                PhosphorMark(size: 104)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)

                // The hero line the whole brand hangs on: the promise, then the
                // thing that makes it unusual, lit.
                VStack(spacing: 0) {
                    Text("Blocks ads everywhere.")
                    Text("Sees nothing.").foregroundStyle(PhosphorTheme.phosphor)
                }
                .font(.system(size: 38, weight: .bold))
                .kerning(-1.4)
                .foregroundStyle(PhosphorTheme.ink50)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

                Text("System-wide filtering for iOS 26 that keeps the URLs you visit encrypted — even from us.")
                    .font(.system(size: 17))
                    .foregroundStyle(PhosphorTheme.ink300)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 28)

                VStack(spacing: 8) {
                    OnboardingFeature(
                        icon: "iphone",
                        title: "Every app, not just Safari",
                        detail: "Ads, trackers, malware, adult content"
                    )
                    OnboardingFeature(
                        icon: "lock.fill",
                        title: "Encrypted lookups",
                        detail: "Apple's Private Information Retrieval"
                    )
                    OnboardingFeature(
                        icon: "arrow.up.right",
                        title: "Zero telemetry, open source",
                        detail: "MIT-licensed. Read every line."
                    )
                }
            }
        } footer: {
            VStack(spacing: 10) {
                PageDots(currentPage: currentPage)

                Button("Continue") {
                    withAnimation { currentPage = 1 }
                }
                .buttonStyle(PhosphorPrimaryButtonStyle())

                Button {
                    isRestoring = true
                    Task {
                        await subscriptionManager.restorePurchases()
                        isRestoring = false
                    }
                } label: {
                    Text(isRestoring ? "Restoring…" : "Restore purchase")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PhosphorTheme.ink400)
                        .frame(height: 44)
                }
                .disabled(isRestoring)
            }
        }
    }
}

// MARK: - Page 2: Privacy

private struct PrivacyPage: View {
    @Binding var currentPage: Int

    var body: some View {
        OnboardingLayout {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingStepHeader(step: "Step 2 of 3") { withAnimation { currentPage = 0 } }

                Text("Nobody sees both.")
                    .font(.system(size: 34, weight: .bold))
                    .kerning(-1.2)
                    .foregroundStyle(PhosphorTheme.ink50)
                    .padding(.bottom, 14)

                Text("Each party in the chain holds one half of the picture and cannot get the other. This is arrangement, not policy.")
                    .font(.system(size: 17))
                    .foregroundStyle(PhosphorTheme.ink300)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)

                VStack(spacing: 10) {
                    ActorCard(
                        title: "Your device",
                        sees: "The URL, the Bloom filter, the decryption key",
                        never: "Sends anything home. There is no telemetry to send."
                    )
                    ActorCard(
                        title: "Apple's relay",
                        sees: "Your IP address and an opaque encrypted blob",
                        never: "What is inside the query — Oblivious HTTP strips it of meaning."
                    )
                    ActorCard(
                        title: "Our PIR server",
                        sees: "A homomorphically encrypted query it computes on blind",
                        never: "Your IP, the URL, or the answer."
                    )
                }
            }
        } footer: {
            VStack(spacing: 10) {
                PageDots(currentPage: currentPage)
                Button("Continue") {
                    withAnimation { currentPage = 2 }
                }
                .buttonStyle(PhosphorPrimaryButtonStyle())
            }
        }
    }
}

// MARK: - Shared layout

/// Scrolling content over the warm-black page, with a footer pinned under it.
struct OnboardingLayout<Content: View, Footer: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            footer
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
        .background(PhosphorTheme.ink950.ignoresSafeArea())
    }
}

/// Back chevron plus the mono step counter.
struct OnboardingStepHeader: View {
    let step: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink50)
                    .frame(width: 44, height: 44)
            }
            .offset(x: -12)
            .accessibilityLabel("Back")

            Spacer()

            Text(step.uppercased())
                .font(PhosphorTheme.eyebrow)
                .tracking(1.0)
                .foregroundStyle(PhosphorTheme.ink400)
        }
        .padding(.bottom, 8)
    }
}

private struct OnboardingFeature: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink50)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(PhosphorTheme.ink400)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .fill(PhosphorTheme.ink900)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .strokeBorder(PhosphorTheme.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ActorCard: View {
    let title: String
    let sees: String
    let never: String

    var body: some View {
        PhosphorCard(padding: 16, radius: PhosphorTheme.tileRadius) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink50)

                VStack(alignment: .leading, spacing: 8) {
                    labelled("SEES", sees, tint: PhosphorTheme.phosphor, body: PhosphorTheme.ink50)
                    labelled("NEVER", never, tint: PhosphorTheme.ink400, body: PhosphorTheme.ink300)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func labelled(_ key: String, _ value: String, tint: Color, body: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key)
                .font(PhosphorTheme.data(11, weight: .regular))
                .tracking(0.7)
                .foregroundStyle(tint)
                .frame(width: 52, alignment: .leading)
                .padding(.top, 2)

            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Page Dots

/// Progress reads as a lit bar for the current page and quiet dots for the rest.
struct PageDots: View {
    let currentPage: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? PhosphorTheme.phosphor : PhosphorTheme.ink50.opacity(0.2))
                    .frame(width: index == currentPage ? 18 : 6, height: 6)
                    .animation(PhosphorTheme.controlAnimation, value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of 3")
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environment(SubscriptionManager())
        .preferredColorScheme(.dark)
}
