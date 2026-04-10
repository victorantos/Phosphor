import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            headerSection
            privacySection
            howItWorksSection
            linksSection
            legalSection
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 48))
                    .foregroundStyle(PhosphorTheme.accent)

                Text("Phosphor")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Privacy-preserving URL filtering for iOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section("Privacy") {
            InfoRow(
                icon: "eye.slash.circle.fill",
                color: .blue,
                title: "Zero Knowledge",
                detail: "Phosphor never sees the URLs you visit. The system checks URLs locally using a Bloom filter. Only potential matches are verified via encrypted PIR queries — and even then, homomorphic encryption means our server can't see the query."
            )
            InfoRow(
                icon: "antenna.radiowaves.left.and.right.slash",
                color: .green,
                title: "Zero Telemetry",
                detail: "No analytics SDKs, no crash reporters, no tracking pixels. Nothing phones home. Your browsing data stays on your device."
            )
            InfoRow(
                icon: "network.badge.shield.half.filled",
                color: .purple,
                title: "Network Anonymity",
                detail: "Even the network connection to our PIR server goes through Apple's Oblivious HTTP relay, so our server never sees your IP address."
            )
        }
    }

    // MARK: - How It Works

    private var howItWorksSection: some View {
        Section("How It Works") {
            VStack(alignment: .leading, spacing: 16) {
                StepExplanation(
                    number: 1,
                    title: "Bloom Filter (On-Device)",
                    detail: "A compact data structure on your device instantly checks if a URL might be in the block list. Most URLs are cleared here with zero network traffic."
                )
                StepExplanation(
                    number: 2,
                    title: "PIR Query (Encrypted)",
                    detail: "For potential matches, the system sends an encrypted query to the PIR server. Homomorphic encryption means the server processes the query without ever decrypting it."
                )
                StepExplanation(
                    number: 3,
                    title: "OHTTP Relay (Anonymous)",
                    detail: "The query is routed through Apple's relay, which strips your IP address. The server sees the query content (encrypted), Apple sees your IP — neither sees both."
                )
                StepExplanation(
                    number: 4,
                    title: "Block or Allow",
                    detail: "The encrypted response is decrypted on your device. If the URL is in the block list, the system prevents the connection. The app never learns which URL was checked."
                )
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Links

    private var linksSection: some View {
        Section("Links") {
            Link(destination: URL(string: "https://developer.apple.com/documentation/networkextension/neurlfiltermanager")!) {
                Label("Apple NEURLFilterManager Docs", systemImage: "book")
            }
            Link(destination: URL(string: "https://developer.apple.com/videos/play/wwdc2025/234/")!) {
                Label("WWDC25 Session 234", systemImage: "play.rectangle")
            }
            Link(destination: URL(string: "https://phosphor.online")!) {
                Label("Website", systemImage: "globe")
            }
            Link(destination: URL(string: "https://github.com/victorantos/Phosphor")!) {
                Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Link(destination: URL(string: "https://phosphor.online/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            Link(destination: URL(string: "https://phosphor.online/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("License")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("MIT License — free to use, modify, and distribute.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Supporting Views

private struct InfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

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
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct StepExplanation: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(PhosphorTheme.accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
