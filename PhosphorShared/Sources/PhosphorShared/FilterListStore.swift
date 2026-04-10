import Foundation
import os

/// Manages persistence of filter lists and their rules in the shared App Group container.
///
/// List metadata is stored as a single JSON file. Each list's rules are stored in
/// separate files to keep memory usage low — the extension only needs to load rules
/// for enabled lists.
///
/// Both the main app and the filter extension access this store. File coordination
/// is not used because the extension and app rarely write simultaneously, and
/// JSON writes are atomic (write-to-temp-then-rename).
public final class FilterListStore: Sendable {
    private let containerURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "FilterListStore")

    /// Name of the metadata file containing all FilterList records.
    private static let metadataFilename = "filter-lists.json"
    /// Name of the block stats file.
    private static let statsFilename = "block-stats.json"
    /// Directory within the container for rule files.
    private static let rulesDirectory = "rules"

    /// Notification name posted via Darwin notifications when lists change.
    /// The extension observes this to reload its dataset.
    public static let listsDidChangeNotification = "com.nestclaw.phosphor.listsDidChange"

    public init(containerURL: URL? = nil) {
        let url = containerURL ?? PhosphorConstants.sharedContainerURL ?? URL.temporaryDirectory
        self.containerURL = url
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Directory Setup

    private var metadataURL: URL {
        containerURL.appendingPathComponent(Self.metadataFilename)
    }

    private var statsURL: URL {
        containerURL.appendingPathComponent(Self.statsFilename)
    }

    private var rulesDirectoryURL: URL {
        containerURL.appendingPathComponent(Self.rulesDirectory)
    }

    private func ensureRulesDirectory() throws {
        try FileManager.default.createDirectory(
            at: rulesDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    // MARK: - List Metadata

    /// Load all filter list metadata.
    public func loadLists() throws -> [FilterList] {
        guard FileManager.default.fileExists(atPath: metadataURL.path()) else {
            return []
        }
        let data = try Data(contentsOf: metadataURL)
        return try decoder.decode([FilterList].self, from: data)
    }

    /// Save all filter list metadata atomically.
    public func saveLists(_ lists: [FilterList]) throws {
        let data = try encoder.encode(lists)
        try atomicWrite(data: data, to: metadataURL)
        postChangeNotification()
        logger.info("Saved \(lists.count) filter list(s)")
    }

    /// Add or update a single filter list.
    public func upsertList(_ list: FilterList) throws {
        var lists = (try? loadLists()) ?? []
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            lists[index] = list
        } else {
            lists.append(list)
        }
        try saveLists(lists)
    }

    /// Remove a filter list and its rules file.
    public func removeList(id: UUID) throws {
        var lists = (try? loadLists()) ?? []
        guard let index = lists.firstIndex(where: { $0.id == id }) else { return }
        let list = lists.remove(at: index)
        try saveLists(lists)
        // Clean up rules file
        let rulesURL = rulesDirectoryURL.appendingPathComponent(list.rulesFilename)
        try? FileManager.default.removeItem(at: rulesURL)
    }

    // MARK: - Rules

    /// Load rules for a specific filter list.
    public func loadRules(for list: FilterList) throws -> [FilterRule] {
        let url = rulesDirectoryURL.appendingPathComponent(list.rulesFilename)
        guard FileManager.default.fileExists(atPath: url.path()) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode([FilterRule].self, from: data)
    }

    /// Save rules for a specific filter list. Updates the list's ruleCount.
    public func saveRules(_ rules: [FilterRule], for list: inout FilterList) throws {
        try ensureRulesDirectory()
        let url = rulesDirectoryURL.appendingPathComponent(list.rulesFilename)
        let data = try encoder.encode(rules)
        try atomicWrite(data: data, to: url)
        list.ruleCount = rules.count
        list.lastUpdated = .now
        try upsertList(list)
        let name = list.name
        logger.info("Saved \(rules.count) rule(s) for list '\(name)'")
    }

    /// Load all block rules from enabled lists. Used by the extension to build the Bloom filter.
    public func loadAllEnabledBlockRules() throws -> [String] {
        let lists = try loadLists().filter(\.isEnabled)
        var urls: [String] = []
        for list in lists {
            let rules = try loadRules(for: list)
            let blockURLs = rules.filter { $0.action == .block }.map(\.url)
            urls.append(contentsOf: blockURLs)
        }
        // Remove any URLs that appear in allow rules
        let allowURLs = try loadAllAllowRules()
        let allowSet = Set(allowURLs)
        return urls.filter { !allowSet.contains($0) }
    }

    /// Load all allow rules from enabled lists.
    private func loadAllAllowRules() throws -> [String] {
        let lists = try loadLists().filter(\.isEnabled)
        var urls: [String] = []
        for list in lists {
            let rules = try loadRules(for: list)
            let allowURLs = rules.filter { $0.action == .allow }.map(\.url)
            urls.append(contentsOf: allowURLs)
        }
        return urls
    }

    // MARK: - Block Stats

    /// Load aggregate block statistics.
    public func loadStats() throws -> BlockStats {
        guard FileManager.default.fileExists(atPath: statsURL.path()) else {
            return BlockStats()
        }
        let data = try Data(contentsOf: statsURL)
        return try decoder.decode(BlockStats.self, from: data)
    }

    /// Save aggregate block statistics.
    public func saveStats(_ stats: BlockStats) throws {
        let data = try encoder.encode(stats)
        try atomicWrite(data: data, to: statsURL)
    }

    // MARK: - Helpers

    /// Write data atomically: write to temp file, then rename.
    private func atomicWrite(data: Data, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tempURL = dir.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tempURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }

    /// Post a Darwin notification so the extension knows lists changed.
    private func postChangeNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(Self.listsDidChangeNotification as CFString),
            nil,
            nil,
            true
        )
    }
}
