import PhosphorShared
import SwiftUI

struct SettingsView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var viewModel = SettingsViewModel()
    @State private var showingImportPicker = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold))
                        .kerning(-1.1)
                        .foregroundStyle(PhosphorTheme.ink50)
                        .padding(.top, 4)

                    statusCard
                    categoriesSection
                    updatesSection
                    subscriptionSection
                    dataSection
                    aboutSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .phosphorPage()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { viewModel.load() }
            .task { await viewModel.observeFilterStatus() }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingImportPicker) {
                ImportDocumentPicker { url in viewModel.importConfig(from: url) }
            }
            .sheet(isPresented: $viewModel.showExportShareSheet) {
                if let url = viewModel.exportURL { ShareSheet(items: [url]) }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }

    // MARK: - Status & pause

    /// The pause segment is derived from how much time is left rather than
    /// stored, so it stays truthful across relaunches.
    private var pauseSelection: SettingsViewModel.PauseDuration? {
        guard let end = viewModel.pauseEndDate, end > .now else { return nil }
        let remaining = end.timeIntervalSinceNow
        if remaining > 3600 { return .untilTomorrow }
        if remaining > 15 * 60 { return .oneHour }
        return .fifteenMinutes
    }

    private var statusCard: some View {
        let paused = viewModel.isPaused
        let running = viewModel.filterIsRunning
        let accent = paused ? PhosphorTheme.signalAmber : (running ? PhosphorTheme.phosphor : PhosphorTheme.signalRed)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PulseDot(size: 12, isLive: running && !paused, color: accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(paused ? "Filtering paused" : (running ? "Filtering active" : "Filtering not active"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PhosphorTheme.ink50)
                    Text(statusSubtitle)
                        .font(PhosphorTheme.data(12, weight: .regular))
                        .foregroundStyle(PhosphorTheme.ink400)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 8) {
                Text("Pause filtering")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink400)

                PhosphorSegmented(
                    options: [
                        (nil, "Off"),
                        (.fifteenMinutes, "15 min"),
                        (.oneHour, "1 hour"),
                        (.untilTomorrow, "Tomorrow"),
                    ],
                    selection: Binding(
                        get: { pauseSelection },
                        set: { newValue in
                            withAnimation(PhosphorTheme.dataAnimation) {
                                if let newValue {
                                    viewModel.pause(duration: newValue)
                                } else {
                                    viewModel.unpause()
                                }
                            }
                        }
                    ),
                    tint: { $0 == nil ? PhosphorTheme.phosphor : PhosphorTheme.signalAmber }
                )
                .accessibilityLabel("Pause filtering")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius, style: .continuous)
                .fill(paused ? PhosphorTheme.signalAmber.opacity(0.06) : PhosphorTheme.ink900)
                .overlay {
                    if !paused {
                        RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [PhosphorTheme.phosphor.opacity(0.12), .clear],
                                    center: .top, startRadius: 0, endRadius: 200
                                )
                            )
                    }
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius, style: .continuous)
                .strokeBorder(accent.opacity(paused ? 0.3 : 0.25), lineWidth: 1)
        }
        .animation(PhosphorTheme.dataAnimation, value: viewModel.isPaused)
    }

    private var statusSubtitle: String {
        if viewModel.isPaused {
            return viewModel.pauseTimeRemaining ?? "Paused"
        }
        let active = viewModel.lists.filter(\.isEnabled)
        let rules = active.reduce(0) { $0 + $1.ruleCount }
        return "\(active.count) lists · \(rules.formatted()) rules"
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        section("Categories") {
            PhosphorGroup {
                ForEach(Array(FilterCategory.allCases.enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: 14) {
                        IconBadge(systemImage: category.systemImage, isOn: viewModel.isEnabled(category))

                        Text(category.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PhosphorTheme.ink50)

                        Spacer(minLength: 0)

                        Toggle("", isOn: Binding(
                            get: { viewModel.isEnabled(category) },
                            set: { _ in
                                withAnimation(PhosphorTheme.dataAnimation) {
                                    viewModel.toggleCategory(category)
                                }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(PhosphorToggleStyle())
                        .accessibilityLabel(category.displayName)
                        .accessibilityHint("Toggles every \(category.displayName.lowercased()) list")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < FilterCategory.allCases.count - 1 { PhosphorDivider(inset: 66) }
                }
            }
        }
    }

    // MARK: - Updates

    private var updatesSection: some View {
        section("Updates") {
            PhosphorGroup {
                Menu {
                    Picker("Refresh frequency", selection: Binding(
                        get: { viewModel.updateFrequency },
                        set: { viewModel.setUpdateFrequency($0) }
                    )) {
                        ForEach(SettingsViewModel.UpdateFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                } label: {
                    PhosphorRow(title: "Update frequency", showsChevron: true) {
                        PhosphorRowValue(text: viewModel.updateFrequency.rawValue)
                    }
                }
                .buttonStyle(PhosphorRowButtonStyle())

                PhosphorDivider()

                PhosphorRow(title: "Last update", subtitle: lastUpdateSubtitle) {
                    Button("Update now") {
                        Task { await refreshAll() }
                    }
                    .buttonStyle(PhosphorPillButtonStyle())
                }
            }
        }
    }

    private var lastUpdateSubtitle: String {
        let rules = viewModel.lists.filter(\.isEnabled).reduce(0) { $0 + $1.ruleCount }
        guard let latest = viewModel.lists.compactMap(\.lastUpdated).max() else {
            return "Never · \(rules.formatted()) rules"
        }
        return "\(latest.formatted(date: .abbreviated, time: .shortened)) · \(rules.formatted()) rules"
    }

    private func refreshAll() async {
        let listViewModel = FilterListViewModel()
        listViewModel.load()
        await listViewModel.refreshAllRemoteLists()
        viewModel.load()
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        section("Subscription") {
            PhosphorGroup {
                if subscriptionManager.isSubscribed {
                    PhosphorRow(title: "Phosphor Premium", subtitle: "Active subscription") {
                        Text("Active")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PhosphorTheme.phosphor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(PhosphorTheme.phosphorTint)
                            )
                    }

                    PhosphorDivider()

                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        PhosphorRow(title: "Manage subscription", showsChevron: true)
                    }
                    .buttonStyle(PhosphorRowButtonStyle())
                } else {
                    PhosphorRow(
                        title: "Phosphor Premium",
                        subtitle: "Required to turn filtering on"
                    )

                    PhosphorDivider()

                    Button {
                        showingPaywall = true
                    } label: {
                        PhosphorRow(title: "View plans", showsChevron: true) {
                            PhosphorRowValue(text: "7 days free")
                        }
                    }
                    .buttonStyle(PhosphorRowButtonStyle())
                }
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        section("Data") {
            PhosphorGroup {
                Button { viewModel.exportConfig() } label: {
                    PhosphorRow(title: "Export configuration", subtitle: "Share your lists and entries as JSON", showsChevron: true)
                }
                .buttonStyle(PhosphorRowButtonStyle())

                PhosphorDivider()

                Button { showingImportPicker = true } label: {
                    PhosphorRow(title: "Import configuration", showsChevron: true)
                }
                .buttonStyle(PhosphorRowButtonStyle())
            }
        }
    }

    // MARK: - Privacy & about

    private var aboutSection: some View {
        section("Privacy & about") {
            PhosphorGroup {
                NavigationLink {
                    AboutView()
                } label: {
                    PhosphorRow(title: "How Phosphor protects you", showsChevron: true)
                }
                .buttonStyle(PhosphorRowButtonStyle())

                PhosphorDivider()

                externalRow("Privacy policy", url: "https://phosphor.online/privacy")
                PhosphorDivider()
                externalRow("Terms of service", url: "https://phosphor.online/terms")
                PhosphorDivider()
                externalRow("Source on GitHub", url: "https://github.com/victorantos/Phosphor")

                PhosphorDivider()

                Button { viewModel.resetOnboarding() } label: {
                    PhosphorRow(title: "Show onboarding again", showsChevron: true)
                }
                .buttonStyle(PhosphorRowButtonStyle())

                PhosphorDivider()

                PhosphorRow(title: "Version") {
                    PhosphorRowValue(text: versionString, mono: true)
                }
            }
        }
    }

    private func externalRow(_ title: String, url: String) -> some View {
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
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    // MARK: - Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            content()
        }
        .padding(.top, 6)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Import Document Picker

struct ImportDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            onPick(url)
        }
    }
}

#Preview {
    SettingsView()
        .environment(SubscriptionManager())
        .preferredColorScheme(.dark)
}
