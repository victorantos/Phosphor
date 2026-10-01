import PhosphorShared
import SwiftUI

struct FilterListDetailView: View {
    let list: FilterList
    let viewModel: FilterListViewModel

    @State private var rules: [FilterRule] = []
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredRules: [FilterRule] {
        if searchText.isEmpty { return rules }
        return rules.filter { $0.url.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            infoSection
            rulesSection
        }
        .scrollContentBackground(.hidden)
        .background(PhosphorTheme.ink950.ignoresSafeArea())
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PhosphorTheme.ink950, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search \(rules.count.formatted()) rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if case .remote = list.source {
                        Button {
                            Task { await viewModel.refreshList(list) }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    if list.source != .bundled {
                        Button(role: .destructive) {
                            viewModel.removeList(list)
                            dismiss()
                        } label: {
                            Label("Delete List", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("List actions")
                }
            }
        }
        .onAppear {
            rules = viewModel.loadRules(for: list)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            LabeledContent("Category") {
                Label(list.category.displayName, systemImage: list.category.systemImage)
            }
            LabeledContent("Rules") {
                Text(list.ruleCount.formatted())
            }
            if let date = list.lastUpdated {
                LabeledContent("Last Updated") {
                    Text(date, style: .relative)
                }
            }
            if case .remote(let url) = list.source {
                LabeledContent("Source") {
                    Link(url.host ?? url.absoluteString, destination: url)
                        .font(.caption)
                        .lineLimit(1)
                        .accessibilityHint("Opens in browser")
                }
            }
            LabeledContent("Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(list.isEnabled ? PhosphorTheme.phosphor : PhosphorTheme.ink600)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(list.isEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(list.isEnabled ? PhosphorTheme.ink50 : PhosphorTheme.ink400)
                }
            }
        }
        .listRowBackground(PhosphorTheme.ink900)
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        Section {
            if filteredRules.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Rules Loaded",
                        systemImage: "doc.text",
                        description: Text("Refresh the list to download rules.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(filteredRules) { rule in
                    HStack {
                        Image(systemName: rule.action == .block ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(rule.action == .block ? PhosphorTheme.signalRed : PhosphorTheme.phosphor)
                            .font(.caption)
                            .accessibilityHidden(true)

                        Text(rule.url)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .swipeActions(edge: .trailing) {
                        if list.source == .manual {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.removeRule(rule, from: list)
                                    rules = viewModel.loadRules(for: list)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .accessibilityLabel("\(rule.action == .block ? "Block" : "Allow") \(rule.url)")
                }
            }
        } header: {
            if !searchText.isEmpty {
                Text("\(filteredRules.count) of \(rules.count) rules")
            } else {
                Text("Rules")
            }
        }
        .listRowBackground(PhosphorTheme.ink900)
    }
}

#Preview {
    NavigationStack {
        FilterListDetailView(
            list: FilterList(
                name: "Peter Lowe's Ad Servers",
                category: .ads,
                source: .bundled,
                isEnabled: true,
                lastUpdated: .now,
                ruleCount: 3526
            ),
            viewModel: FilterListViewModel()
        )
    }
}
