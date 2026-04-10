import PhosphorShared
import SwiftUI

struct SettingsView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var viewModel = SettingsViewModel()
    @State private var showingImportPicker = false
    @State private var showingPauseOptions = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                filteringSection
                pauseSection
                updateSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear { viewModel.load() }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingImportPicker) {
                ImportDocumentPicker { url in
                    viewModel.importConfig(from: url)
                }
            }
            .sheet(isPresented: $viewModel.showExportShareSheet) {
                if let url = viewModel.exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        Section {
            if subscriptionManager.isSubscribed {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Phosphor Premium")
                                .fontWeight(.semibold)
                            Text("Active subscription")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(PhosphorTheme.accent)
                    }
                    Spacer()
                }
                Button("Manage Subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Phosphor Premium")
                                .fontWeight(.semibold)
                            Text("Subscribe to enable URL filtering")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                }
                Button {
                    showingPaywall = true
                } label: {
                    Text("View Plans")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PhosphorTheme.accent)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    // MARK: - Filtering Categories

    private var filteringSection: some View {
        Section {
            ForEach(FilterCategory.allCases) { category in
                Toggle(isOn: Binding(
                    get: { viewModel.isEnabled(category) },
                    set: { _ in
                        withAnimation(PhosphorTheme.dataAnimation) {
                            viewModel.toggleCategory(category)
                        }
                    }
                )) {
                    Label(category.displayName, systemImage: category.systemImage)
                }
                .tint(PhosphorTheme.accent)
                .accessibilityHint("Toggles all \(category.displayName.lowercased()) filter lists")
            }
        } header: {
            Text("Categories")
        } footer: {
            Text("Toggle entire categories on or off. Individual lists can be managed in the Lists tab.")
        }
    }

    // MARK: - Pause

    private var pauseSection: some View {
        Section("Pause Filtering") {
            if viewModel.isPaused {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Filtering Paused")
                                .foregroundStyle(.orange)
                            if let remaining = viewModel.pauseTimeRemaining {
                                Text(remaining)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    Button("Resume") {
                        withAnimation { viewModel.unpause() }
                    }
                    .buttonStyle(.bordered)
                    .tint(PhosphorTheme.accent)
                    .accessibilityHint("Resumes URL filtering immediately")
                }
            } else {
                Button {
                    showingPauseOptions = true
                } label: {
                    Label("Pause Filtering", systemImage: "pause.circle")
                }
                .confirmationDialog("Pause Filtering", isPresented: $showingPauseOptions) {
                    ForEach(SettingsViewModel.PauseDuration.allCases, id: \.self) { duration in
                        Button(duration.rawValue) {
                            viewModel.pause(duration: duration)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("URLs will not be filtered during the pause period.")
                }
            }
        }
    }

    // MARK: - Update Frequency

    private var updateSection: some View {
        Section("List Updates") {
            Picker("Refresh Frequency", selection: Binding(
                get: { viewModel.updateFrequency },
                set: { viewModel.setUpdateFrequency($0) }
            )) {
                ForEach(SettingsViewModel.UpdateFrequency.allCases) { freq in
                    Text(freq.rawValue).tag(freq)
                }
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data") {
            Button {
                viewModel.exportConfig()
            } label: {
                Label("Export Configuration", systemImage: "square.and.arrow.up")
            }

            Button {
                showingImportPicker = true
            } label: {
                Label("Import Configuration", systemImage: "square.and.arrow.down")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                Label("About Phosphor", systemImage: "info.circle")
            }

            Button {
                viewModel.resetOnboarding()
            } label: {
                Label("Show Onboarding Again", systemImage: "arrow.counterclockwise")
            }
        }
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
}
