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
        .listStyle(.insetGrouped)
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(list.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    sourceLabel

                    Text("\(list.ruleCount.formatted()) rules")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let date = list.lastUpdated {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

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
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(list.name), \(list.ruleCount) rules")
        .accessibilityValue(list.isEnabled ? "Enabled" : "Disabled")
        .accessibilityHint("Double-tap to \(list.isEnabled ? "disable" : "enable")")
    }

    @ViewBuilder
    private var sourceLabel: some View {
        let (text, color): (String, Color) = switch list.source {
        case .bundled: ("Bundled", PhosphorTheme.accent)
        case .remote: ("Remote", .blue)
        case .manual: ("Custom", .orange)
        }
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

#Preview {
    FilterListsView()
}
