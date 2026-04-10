import Foundation
import Observation
import os
import PhosphorShared

@Observable
@MainActor
final class FilterListViewModel {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "FilterListVM")

    private let store: FilterListStore

    var lists: [FilterList] = []
    var isLoading = false
    var errorMessage: String?

    /// Grouped lists by category for the UI.
    var listsByCategory: [FilterCategory: [FilterList]] {
        Dictionary(grouping: lists, by: \.category)
    }

    init(store: FilterListStore = FilterListStore()) {
        self.store = store
    }

    // MARK: - Load

    func load() {
        do {
            lists = try store.loadLists()
            errorMessage = nil
            Self.logger.info("Loaded \(self.lists.count) filter list(s)")
        } catch {
            errorMessage = error.localizedDescription
            Self.logger.error("Failed to load lists: \(error.localizedDescription)")
        }
    }

    // MARK: - Toggle

    func toggleList(_ list: FilterList) {
        guard var updated = lists.first(where: { $0.id == list.id }) else { return }
        updated.isEnabled.toggle()
        do {
            try store.upsertList(updated)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Add Custom List

    func addCustomList(name: String, category: FilterCategory, sourceURL: URL) {
        let list = FilterList(
            name: name,
            category: category,
            source: .remote(sourceURL),
            isEnabled: true
        )
        do {
            try store.upsertList(list)
            load()
            Self.logger.info("Added custom list '\(name)'")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Add a manual block/allow entry.
    func addManualEntry(url: String, action: RuleAction, category: FilterCategory) {
        // Find or create the manual list for this category
        var manualList = lists.first(where: { $0.category == category && $0.source == .manual })
        if manualList == nil {
            manualList = FilterList(
                name: "\(category.displayName) (Custom)",
                category: category,
                source: .manual,
                isEnabled: true
            )
        }

        guard var list = manualList else { return }

        do {
            var rules = try store.loadRules(for: list)
            rules.append(FilterRule(url: url, action: action))
            try store.saveRules(rules, for: &list)
            load()
            Self.logger.info("Added manual \(action.rawValue) entry: \(url)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Remove

    func removeList(_ list: FilterList) {
        do {
            try store.removeList(id: list.id)
            load()
            Self.logger.info("Removed list '\(list.name)'")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeRule(_ rule: FilterRule, from list: FilterList) {
        guard var mutableList = lists.first(where: { $0.id == list.id }) else { return }
        do {
            var rules = try store.loadRules(for: mutableList)
            rules.removeAll { $0.id == rule.id }
            try store.saveRules(rules, for: &mutableList)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh Remote Lists

    func refreshList(_ list: FilterList) async {
        guard case .remote(let url) = list.source else { return }
        isLoading = true
        defer { isLoading = false }

        Self.logger.info("Refreshing list '\(list.name)' from \(url.absoluteString)")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let text = String(data: data, encoding: .utf8) else {
                errorMessage = "Could not decode list data"
                return
            }

            let domains = parseHostsList(text)
            guard var mutableList = lists.first(where: { $0.id == list.id }) else { return }

            let rules = domains.map { FilterRule(url: $0) }
            try store.saveRules(rules, for: &mutableList)
            load()

            Self.logger.info("Refreshed '\(list.name)': \(domains.count) domains")
        } catch {
            errorMessage = "Refresh failed: \(error.localizedDescription)"
            Self.logger.error("Refresh failed for '\(list.name)': \(error.localizedDescription)")
        }
    }

    func refreshAllRemoteLists() async {
        let remoteLists = lists.filter {
            if case .remote = $0.source { return true }
            return false
        }
        for list in remoteLists {
            await refreshList(list)
        }
    }

    // MARK: - Helpers

    func loadRules(for list: FilterList) -> [FilterRule] {
        (try? store.loadRules(for: list)) ?? []
    }

    /// Parse a hosts-format or plain-domain text file into a domain list.
    private func parseHostsList(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { line in
                let stripped = line.replacingOccurrences(
                    of: "#.*$",
                    with: "",
                    options: .regularExpression
                ).trimmingCharacters(in: .whitespaces)
                // Remove hosts-file prefix (0.0.0.0 or 127.0.0.1)
                return stripped
                    .replacingOccurrences(of: "^(0\\.0\\.0\\.0|127\\.0\\.0\\.1)\\s+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
            }
            .filter { !$0.isEmpty && !$0.starts(with: "localhost") && $0.contains(".") }
    }
}
