import Foundation
import os

/// Parameters describing a Bloom filter saved by `PrefilterStore`.
public struct PrefilterMetadata: Codable, Sendable, Equatable {
    public let tag: String
    public let bitCount: Int
    public let hashCount: Int
    public let murmurSeed: UInt32
    public let urlCount: Int
}

/// Persists the prebuilt Bloom filter in the shared App Group container.
///
/// The filter extension runs under a 6 MB memory limit, far too little to load
/// the rule lists and build the filter itself. The app builds it here and the
/// extension only reads the finished bytes.
public final class PrefilterStore: Sendable {
    private let containerURL: URL
    private let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "PrefilterStore")

    private static let dataFilename = "prefilter.bin"
    private static let metadataFilename = "prefilter.json"
    private static let falsePositiveRate = 0.001

    /// Apple's onboarding checks that this URL is blocked. The PIR database lists it,
    /// so the prefilter has to let it through to the server.
    private static let onboardingTestEntries = [
        "www.apple.com/url-filter-test",
        "apple.com/url-filter-test",
    ]

    public init(containerURL: URL? = nil) {
        self.containerURL = containerURL ?? PhosphorConstants.sharedContainerURL ?? URL.temporaryDirectory
    }

    private var dataURL: URL {
        containerURL.appendingPathComponent(Self.dataFilename)
    }

    private var metadataURL: URL {
        containerURL.appendingPathComponent(Self.metadataFilename)
    }

    /// The form the system looks a URL up in: it drops a leading `www.` before checking
    /// the prefilter, so an entry that keeps it can never match. Duplicates are removed
    /// and the result is sorted, which keeps the filter's tag stable.
    public static func normalized(_ urls: [String]) -> [String] {
        var seen = Set<String>()
        for url in urls {
            let lowered = url.lowercased()
            seen.insert(lowered.hasPrefix("www.") ? String(lowered.dropFirst(4)) : lowered)
        }
        return seen.sorted()
    }

    // MARK: - Building (app only)

    /// Build the filter from the enabled block rules and save it.
    /// Removes any saved filter when there is nothing to block.
    @discardableResult
    public func rebuild(from store: FilterListStore) throws -> PrefilterMetadata? {
        var urls = try store.loadAllEnabledBlockRules()
        guard !urls.isEmpty else {
            try? FileManager.default.removeItem(at: metadataURL)
            try? FileManager.default.removeItem(at: dataURL)
            logger.info("No enabled block rules, removed saved prefilter")
            return nil
        }

        urls.append(contentsOf: Self.onboardingTestEntries)
        urls = Self.normalized(urls)
        let filter = BloomFilter.build(urls: urls, falsePositiveRate: Self.falsePositiveRate)
        let metadata = PrefilterMetadata(
            tag: filter.tag,
            bitCount: filter.bitCount,
            hashCount: filter.hashCount,
            murmurSeed: filter.murmurSeed,
            urlCount: urls.count
        )

        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        // Data first: a reader that sees the new metadata must find matching bytes.
        try filter.data.write(to: dataURL, options: .atomic)
        try JSONEncoder().encode(metadata).write(to: metadataURL, options: .atomic)
        logger.info("Saved prefilter: \(urls.count) URLs, \(filter.bitCount) bits, \(filter.hashCount) hashes")
        return metadata
    }

    /// Rebuilds from the current lists and returns the saved filter's parameters, or nil
    /// when there is nothing to block. Rebuilds run one at a time.
    public static func rebuildFromCurrentLists() async -> PrefilterMetadata? {
        await Rebuilder.shared.rebuild()
    }

    /// Runs rebuilds one at a time so the saved bytes and parameters always match.
    private actor Rebuilder {
        static let shared = Rebuilder()
        private let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "PrefilterStore")

        func rebuild() -> PrefilterMetadata? {
            do {
                return try PrefilterStore().rebuild(from: FilterListStore())
            } catch {
                logger.error("Rebuilding prefilter failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }

    // MARK: - Reading (extension)

    /// Parameters of the saved filter, or nil when none has been built.
    public func loadMetadata() throws -> PrefilterMetadata? {
        guard FileManager.default.fileExists(atPath: metadataURL.path()) else { return nil }
        return try JSONDecoder().decode(PrefilterMetadata.self, from: Data(contentsOf: metadataURL))
    }

    /// The saved filter bytes, memory-mapped to stay within the extension's limit.
    public func loadData() throws -> Data {
        try Data(contentsOf: dataURL, options: .mappedIfSafe)
    }
}
