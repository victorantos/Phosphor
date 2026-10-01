import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                promiseCard
                mechanismSection
                linksSection
                licenseSection
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .phosphorPage()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PhosphorTheme.ink950, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            PhosphorMark(size: 72)

            Text("phosphor")
                .font(.system(size: 26, weight: .bold))
                .kerning(-0.9)
                .foregroundStyle(PhosphorTheme.ink50)

            Text("Privacy-preserving, system-wide URL filtering for iOS 26.")
                .font(.system(size: 15))
                .foregroundStyle(PhosphorTheme.ink300)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(build))")
                    .font(PhosphorTheme.data(12, weight: .regular))
                    .foregroundStyle(PhosphorTheme.ink400)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Promise

    private var promiseCard: some View {
        PhosphorCard(padding: 20, lit: true) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nobody sees both")
                    .font(.system(size: 22, weight: .semibold))
                    .kerning(-0.5)
                    .foregroundStyle(PhosphorTheme.ink50)

                Text("This is not a policy promise — it is how the pieces are arranged. Each party in the chain holds one half of the picture and cannot get the other.")
                    .font(.system(size: 15))
                    .foregroundStyle(PhosphorTheme.ink300)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Fact("Your device", "Sees the URL, the Bloom filter and the decryption key. Sends nothing home — there is no telemetry to send.")
                    Fact("Apple's relay", "Sees your IP address and an opaque encrypted blob. Never what is inside the query.")
                    Fact("Our PIR server", "Sees a homomorphically encrypted query it computes on blind. Never your IP, the URL, or the answer.")
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Mechanism

    private var mechanismSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("How it works")

            VStack(spacing: 10) {
                Step(1, "Bloom filter, on device", "A compact bit array instantly checks if a URL might be blocked. Most URLs are cleared here with zero network traffic.", lit: true)
                Step(2, "Encrypted PIR query", "For a possible match, the system sends a homomorphically encrypted query. The server answers it without ever decrypting it.")
                Step(3, "Apple's OHTTP relay", "Queries route through Apple's Oblivious HTTP relay. Your IP is hidden from our server; the query is hidden from Apple.")
                Step(4, "Block or allow", "The encrypted response is decrypted on your device. The app never learns which URL was checked.")
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Links")

            PhosphorGroup {
                linkRow("Website", "https://phosphor.online")
                PhosphorDivider()
                linkRow("Privacy policy", "https://phosphor.online/privacy")
                PhosphorDivider()
                linkRow("Terms of service", "https://phosphor.online/terms")
                PhosphorDivider()
                linkRow("Source on GitHub", "https://github.com/victorantos/Phosphor")
                PhosphorDivider()
                linkRow("Apple NEURLFilterManager docs", "https://developer.apple.com/documentation/networkextension/neurlfiltermanager")
                PhosphorDivider()
                linkRow("WWDC25 session 234", "https://developer.apple.com/videos/play/wwdc2025/234/")
            }
        }
        .padding(.top, 6)
    }

    private func linkRow(_ title: String, _ url: String) -> some View {
        Button {
            if let url = URL(string: url) { UIApplication.shared.open(url) }
        } label: {
            PhosphorRow(title: title) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink400)
            }
        }
        .buttonStyle(PhosphorRowButtonStyle())
        .accessibilityHint("Opens in browser")
    }

    // MARK: - License

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("License")

            PhosphorCard(padding: 16) {
                Text("The app, the filter extension and the shared Bloom filter are MIT-licensed — free to use, modify and distribute. The Phosphor name and mark are proprietary.")
                    .font(.system(size: 15))
                    .foregroundStyle(PhosphorTheme.ink300)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Supporting views

private struct Fact: View {
    let title: String
    let detail: String

    init(_ title: String, _ detail: String) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(PhosphorTheme.phosphor)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink50)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(PhosphorTheme.ink300)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Step: View {
    let number: Int
    let title: String
    let detail: String
    let lit: Bool

    init(_ number: Int, _ title: String, _ detail: String, lit: Bool = false) {
        self.number = number
        self.title = title
        self.detail = detail
        self.lit = lit
    }

    var body: some View {
        PhosphorCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(String(format: "%02d", number))
                        .font(PhosphorTheme.data(13))
                        .foregroundStyle(lit ? PhosphorTheme.ink950 : PhosphorTheme.ink300)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle()
                                .fill(lit ? PhosphorTheme.phosphor : PhosphorTheme.fill)
                                .shadow(color: lit ? PhosphorTheme.phosphor.opacity(0.5) : .clear, radius: 8)
                        }
                        .overlay {
                            if !lit {
                                Circle().strokeBorder(PhosphorTheme.line, lineWidth: 1)
                            }
                        }

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: lit
                                    ? [PhosphorTheme.phosphor, PhosphorTheme.phosphor.opacity(0.05)]
                                    : [PhosphorTheme.ink50.opacity(0.2), PhosphorTheme.ink50.opacity(0.02)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .kerning(-0.4)
                        .foregroundStyle(PhosphorTheme.ink50)
                    Text(detail)
                        .font(.system(size: 15))
                        .foregroundStyle(PhosphorTheme.ink300)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title). \(detail)")
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}
