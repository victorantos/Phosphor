import PhosphorShared
import SwiftUI

struct FilterListsView: View {
    @State private var viewModel = FilterListViewModel()
    @State private var showingAddSheet = false
    @State private var showingAddEntry = false

    private var builtIn: [FilterList] { viewModel.lists.filter(\.isBuiltIn) }
    private var custom: [FilterList] {
        viewModel.lists.filter { list in
            if case .remote = list.source { return !list.isBuiltIn } else { return false }
        }
    }
    private var manual: [FilterList] { viewModel.lists.filter { $0.source == .manual } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if viewModel.lists.isEmpty {
                        emptyState
                    } else {
                        if !builtIn.isEmpty {
                            section("Built-in") { group(builtIn) }
                        }

                        section("Custom") {
                            VStack(spacing: 10) {
                                if !custom.isEmpty { group(custom) }
                                addListTile
                            }
                        }

                        if !manual.isEmpty {
                            section("Manual entries") { group(manual) }
                        }

                        reopenNote
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .phosphorPage()
            .toolbar(.hidden, for: .navigationBar)
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
                        .tint(PhosphorTheme.phosphor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PhosphorTheme.ink950.opacity(0.6))
                        .ignoresSafeArea()
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Lists")
                    .font(.system(size: 32, weight: .bold))
                    .kerning(-1.1)
                    .foregroundStyle(PhosphorTheme.ink50)

                Spacer()

                Menu {
                    Button { showingAddSheet = true } label: {
                        Label("Add remote list", systemImage: "plus")
                    }
                    Button { showingAddEntry = true } label: {
                        Label("Add manual entry", systemImage: "pencil.line")
                    }
                    Divider()
                    Button {
                        Task { await viewModel.refreshAllRemoteLists() }
                    } label: {
                        Label("Refresh all", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(PhosphorPillButtonStyle())
                .accessibilityLabel("Add or refresh lists")
            }

            Text(summaryLine)
                .font(PhosphorTheme.data(12, weight: .regular))
                .foregroundStyle(PhosphorTheme.ink400)
        }
        .padding(.top, 4)
    }

    private var summaryLine: String {
        let active = viewModel.lists.filter(\.isEnabled).count
        let rules = viewModel.lists.filter(\.isEnabled).reduce(0) { $0 + $1.ruleCount }
        var parts = ["\(active) active", "\(rules.formatted()) rules"]
        if let latest = viewModel.lists.compactMap(\.lastUpdated).max() {
            parts.append("updated \(latest.formatted(.relative(presentation: .numeric)))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Sections

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            content()
        }
        .padding(.top, 6)
    }

    private func group(_ lists: [FilterList]) -> some View {
        PhosphorGroup {
            ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                FilterListRow(list: list, viewModel: viewModel)
                if index < lists.count - 1 { PhosphorDivider(inset: 66) }
            }
        }
        .animation(PhosphorTheme.dataAnimation, value: lists.map(\.id))
    }

    /// iOS hands each app the filter when the app starts, so a running app keeps the
    /// lists it started with.
    private var reopenNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 16))
                .foregroundStyle(PhosphorTheme.ink400)
                .padding(.top, 1)

            Text("Changes apply to an app the next time it is opened. Close Safari and open it again to see them there.")
                .font(.system(size: 14))
                .foregroundStyle(PhosphorTheme.ink300)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .fill(PhosphorTheme.ink50.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: PhosphorTheme.tileRadius, style: .continuous)
                .strokeBorder(
                    PhosphorTheme.ink50.opacity(0.16),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                )
        }
        .accessibilityElement(children: .combine)
    }

    private var addListTile: some View {
        Button {
            showingAddSheet = true
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemImage: "plus", isOn: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a filter list")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PhosphorTheme.ink50)
                    Text("Paste a hosts-format or domain-list URL")
                        .font(.system(size: 13))
                        .foregroundStyle(PhosphorTheme.ink400)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: PhosphorTheme.cardRadius, style: .continuous)
                    .strokeBorder(
                        PhosphorTheme.ink50.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        PhosphorCard(padding: 28) {
            VStack(spacing: 14) {
                IconBadge(systemImage: "list.bullet.rectangle.fill", isOn: false, size: 52)
                Text("No filter lists")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PhosphorTheme.ink50)
                Text("Add a list to start blocking ads, trackers and malware.")
                    .font(.system(size: 15))
                    .foregroundStyle(PhosphorTheme.ink300)
                    .multilineTextAlignment(.center)
                Button("Add remote list") { showingAddSheet = true }
                    .buttonStyle(PhosphorPrimaryButtonStyle())
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 12)
    }
}

// MARK: - Row

private struct FilterListRow: View {
    let list: FilterList
    let viewModel: FilterListViewModel

    var body: some View {
        HStack(spacing: 14) {
            NavigationLink {
                FilterListDetailView(list: list, viewModel: viewModel)
            } label: {
                HStack(spacing: 14) {
                    IconBadge(systemImage: list.category.systemImage, isOn: list.isEnabled)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(list.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(list.isEnabled ? PhosphorTheme.ink50 : PhosphorTheme.ink300)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(PhosphorTheme.data(12, weight: .regular))
                            .foregroundStyle(PhosphorTheme.ink400)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { list.isEnabled },
                set: { _ in
                    withAnimation(PhosphorTheme.dataAnimation) { viewModel.toggleList(list) }
                }
            ))
            .labelsHidden()
            .toggleStyle(PhosphorToggleStyle())
            .accessibilityLabel("\(list.name) enabled")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var subtitle: String {
        var parts = [list.category.displayName, "\(list.ruleCount.formatted()) rules"]
        if case .remote = list.source, !list.isBuiltIn { parts.append("Remote") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    FilterListsView()
        .preferredColorScheme(.dark)
}

/// Lists that ship with the app. Those that update from the web are stored with a remote
/// source, so they are recognised by name against the bundled manifest.
private let bundledListNames = BundledListLoader.bundledListNames()

private extension FilterList {
    var isBuiltIn: Bool {
        source == .bundled || (source != .manual && bundledListNames.contains(name))
    }
}
