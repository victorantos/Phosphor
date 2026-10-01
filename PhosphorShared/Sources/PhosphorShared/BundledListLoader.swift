import Foundation
import os

/// Metadata for a bundled filter list, matching the bundled-lists.json manifest.
struct BundledListManifestEntry: Codable, Sendable {
    let name: String
    let category: FilterCategory
    let filename: String
    let sourceURL: String
    let description: String
}

/// Loads bundled filter list JSON files and imports them into the FilterListStore
/// on first launch. Subsequent launches skip import unless a version bump occurs.
public final class BundledListLoader: Sendable {
    /// Increment this when bundled lists are updated to trigger a re-import.
    public static let bundledListVersion = 3

    private static let versionKey = "bundledListVersion"
    private let store: FilterListStore
    private let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "BundledListLoader")

    public init(store: FilterListStore) {
        self.store = store
    }

    /// Names of the lists that ship with the app. Bundled lists that update from the web
    /// are stored with a remote source, so the source alone does not identify them.
    public static func bundledListNames(in bundle: Bundle = .main) -> Set<String> {
        guard let url = bundle.url(forResource: "bundled-lists", withExtension: "json", subdirectory: "BundledLists")
                ?? bundle.url(forResource: "bundled-lists", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([BundledListManifestEntry].self, from: data)
        else { return [] }
        return Set(entries.map(\.name))
    }

    /// Returns true if bundled lists have already been imported at the current version.
    public var hasImported: Bool {
        let stored = PhosphorConstants.sharedDefaults?.integer(forKey: Self.versionKey) ?? 0
        return stored >= Self.bundledListVersion
    }

    /// Import bundled lists from a resource bundle. Call on first launch.
    /// - Parameter bundle: The bundle containing `BundledLists/` resources.
    public func importIfNeeded(from bundle: Bundle = .main) throws {
        guard !hasImported else {
            logger.info("Bundled lists already imported (v\(Self.bundledListVersion))")
            return
        }
        let stored = PhosphorConstants.sharedDefaults?.integer(forKey: Self.versionKey) ?? 0
        try importBundledLists(from: bundle)
        if stored == 1 {
            try enableAllBundledLists()
        }
        PhosphorConstants.sharedDefaults?.set(Self.bundledListVersion, forKey: Self.versionKey)
        logger.info("Bundled lists imported successfully")
    }

    /// Version 1 imported the adult content list switched off. Every bundled list is
    /// now on by default, so switch on the ones an earlier import left off.
    private func enableAllBundledLists() throws {
        let lists = try store.loadLists().map { list in
            var list = list
            if list.source != .manual {
                list.isEnabled = true
            }
            return list
        }
        try store.saveLists(lists)
        logger.info("Enabled all bundled filter lists")
    }

    private func importBundledLists(from bundle: Bundle) throws {
        guard let manifestURL = bundle.url(
            forResource: "bundled-lists",
            withExtension: "json",
            subdirectory: "BundledLists"
        ) else {
            // Try without subdirectory (flat resource bundle)
            guard let flatURL = bundle.url(forResource: "bundled-lists", withExtension: "json") else {
                logger.warning("bundled-lists.json not found in bundle")
                return
            }
            try importFromManifest(at: flatURL, bundle: bundle, subdirectory: nil)
            return
        }
        try importFromManifest(at: manifestURL, bundle: bundle, subdirectory: "BundledLists")
    }

    private func importFromManifest(at url: URL, bundle: Bundle, subdirectory: String?) throws {
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([BundledListManifestEntry].self, from: data)

        var lists: [FilterList] = []
        // A later version of the bundle can add lists. Lists already imported are left
        // alone so that switching one off survives an update.
        let existingNames = Set((try? store.loadLists())?.map(\.name) ?? [])

        for entry in entries where !existingNames.contains(entry.name) {
            let resourceName = (entry.filename as NSString).deletingPathExtension
            let resourceExt = (entry.filename as NSString).pathExtension

            guard let domainsURL = bundle.url(
                forResource: resourceName,
                withExtension: resourceExt,
                subdirectory: subdirectory
            ) ?? bundle.url(forResource: resourceName, withExtension: resourceExt) else {
                logger.warning("Missing bundled list file: \(entry.filename)")
                continue
            }

            let domainsData = try Data(contentsOf: domainsURL)
            let domains = try JSONDecoder().decode([String].self, from: domainsData)

            let sourceURL = URL(string: entry.sourceURL)
            let source: FilterListSource = sourceURL.map { .remote($0) } ?? .bundled

            var list = FilterList(
                name: entry.name,
                category: entry.category,
                source: source,
                isEnabled: true,
                lastUpdated: .now,
                ruleCount: domains.count
            )

            let rules = domains.map { FilterRule(url: $0) }
            try store.saveRules(rules, for: &list)
            lists.append(list)

            logger.info("Imported \(domains.count) domains for '\(entry.name)'")
        }

        logger.info("Imported \(lists.count) bundled filter list(s)")
    }
}
