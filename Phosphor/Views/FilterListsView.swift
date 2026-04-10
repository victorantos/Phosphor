import PhosphorShared
import SwiftUI

struct FilterListsView: View {
    @State private var viewModel = FilterListViewModel()
    @State private var showingAddSheet = false
    @State private var showingAddEntry = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.lists.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Filter Lists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Label("Add Remote List", systemImage: "plus")
                        }
                        Button {
                            showingAddEntry = true
                        } label: {
                            Label("Add Manual Entry", systemImage: "pencil.line")
                        }
                        Divider()
                        Button {
                            Task { await viewModel.refreshAllRemoteLists() }
                        } label: {
                            Label("Refresh All", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .accessibilityLabel("Add or refresh lists")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddCustomListView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAddEntry) {
                AddManualEntryView(viewModel: viewModel)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                        .accessibilityLabel("Loading filter lists")
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .onAppear { viewModel.load() }
    }

    // MARK: - List Content

    private var listContent: some View {
        List {
            ForEach(FilterCategory.allCases) { category in
                let categoryLists = viewModel.listsByCategory[category] ?? []
                if !categoryLists.isEmpty {
                    Section {
                        ForEach(categoryLists) { list in
                            NavigationLink {
                                FilterListDetailView(list: list, viewModel: viewModel)
                            } label: {
                                FilterListRow(list: list, viewModel: viewModel)
                            }
                        }
                    } header: {
                        Label(category.displayName, systemImage: category.systemImage)
                    } footer: {
                        let total = categoryLists.reduce(0) { $0 + $1.ruleCount }
                        Text("\(total.formatted()) rules")
                    }
                }
            }
        }
        .animation(PhosphorTheme.dataAnimation, value: viewModel.lists.map(\.id))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Filter Lists", systemImage: "list.bullet.rectangle.fill")
        } description: {
            Text("Add filter lists to start blocking ads, trackers, and malware.")
        } actions: {
            Button("Add Remote List") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(PhosphorTheme.accent)
        }
    }
}

// MARK: - Row

private struct FilterListRow: View {
    let list: FilterList
    let viewModel: FilterListViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(list.ruleCount.formatted()) rules")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let date = list.lastUpdated {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    sourceLabel
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { list.isEnabled },
                set: { _ in
                    withAnimation(PhosphorTheme.dataAnimation) {
                        viewModel.toggleList(list)
                    }
                }
            ))
            .labelsHidden()
            .tint(PhosphorTheme.accent)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(list.name), \(list.ruleCount) rules")
        .accessibilityValue(list.isEnabled ? "Enabled" : "Disabled")
        .accessibilityHint("Double-tap to \(list.isEnabled ? "disable" : "enable")")
    }

    @ViewBuilder
    private var sourceLabel: some View {
        switch list.source {
        case .bundled:
            Text("Bundled")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(PhosphorTheme.accentMuted, in: Capsule())
        case .remote:
            Text("Remote")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.15), in: Capsule())
        case .manual:
            Text("Custom")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15), in: Capsule())
        }
    }
}

#Preview {
    FilterListsView()
}
