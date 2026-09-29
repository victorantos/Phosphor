import ExtensionFoundation
import NetworkExtension
import os
import PhosphorShared

@main
class FilterControlProvider: NEURLFilterControlProvider {
    private let logger = Logger(
        subsystem: "com.nestclaw.phosphor.filter-extension",
        category: "FilterControl"
    )

    required init() {
        logger.info("FilterControlProvider init")
    }

    func start() async throws {
        logger.info("Filter extension started")
    }

    func stop(reason: NEProviderStopReason) async throws {
        logger.info("Filter extension stopped")
    }

    /// Hands the system the Bloom filter it checks every URL against before it
    /// spends a PIR query. Returns nil when the system already holds the current one.
    ///
    /// The app builds the filter; this process is limited to 6 MB and is killed
    /// if it loads the rule lists itself.
    func fetchPrefilter(existingPrefilterTag: String?) async throws -> NEURLFilterPrefilter? {
        logger.info("fetchPrefilter called, existing tag: \(existingPrefilterTag ?? "none", privacy: .public)")

        let store = PrefilterStore()
        guard let metadata = try store.loadMetadata() else {
            logger.warning("No saved prefilter, nothing to return")
            return nil
        }

        guard metadata.tag != existingPrefilterTag else {
            logger.info("Prefilter unchanged")
            return nil
        }

        let data = try store.loadData()
        logger.info("Returning prefilter: \(metadata.urlCount) URLs, \(metadata.bitCount) bits, \(metadata.hashCount) hashes")
        return NEURLFilterPrefilter(
            data: .smallFilter(data),
            tag: metadata.tag,
            bitCount: metadata.bitCount,
            hashCount: metadata.hashCount,
            murmurSeed: metadata.murmurSeed
        )
    }
}
