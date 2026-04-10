import NetworkExtension
import os
import PhosphorShared

// NOTE: NEURLFilterControlProvider is a protocol (AppExtension) in iOS 26.
// This will only compile with the Xcode 26+ SDK.

@main
struct FilterControlProvider: NEURLFilterControlProvider {
    private static let logger = Logger(
        subsystem: "com.example.phosphor.filter-extension",
        category: "FilterControl"
    )

    /// Shared store for reading filter lists from the App Group container.
    private static let store = FilterListStore()

    /// The current Bloom filter and its tag, rebuilt when lists change.
    private static var currentFilter: BloomFilter?
    private static var currentTag: String?

    // MARK: - Extension Lifecycle

    func start() async throws {
        Self.logger.info("Filter extension starting")
        rebuildFilterIfNeeded()
        observeListChanges()
        Self.logger.info("Filter extension started, filter tag: \(Self.currentTag ?? "none")")
    }

    func stop(reason: NEProviderStopReason) async throws {
        Self.logger.info("Filter extension stopping, reason: \(String(describing: reason))")
    }

    // MARK: - Prefilter

    func fetchPrefilter(existingPrefilterTag: String?) async throws -> NEURLFilterPrefilter? {
        Self.logger.info("fetchPrefilter called, existingTag: \(existingPrefilterTag ?? "nil")")

        // Rebuild in case lists changed since last fetch
        rebuildFilterIfNeeded()

        guard let filter = Self.currentFilter, let tag = Self.currentTag else {
            Self.logger.warning("No filter available — no enabled block rules")
            return nil
        }

        // If the tag matches, the system already has our current filter
        if existingPrefilterTag == tag {
            Self.logger.info("Prefilter unchanged (tag matches), returning nil")
            return nil
        }

        Self.logger.info("Returning prefilter: \(filter.bitCount) bits, \(filter.hashCount) hashes, tag: \(tag)")

        return NEURLFilterPrefilter(
            data: .smallFilter(filter.data),
            tag: tag,
            bitCount: filter.bitCount,
            hashCount: filter.hashCount,
            murmurSeed: filter.murmurSeed
        )
    }

    // MARK: - Filter Building

    /// Rebuild the Bloom filter from enabled block rules.
    private func rebuildFilterIfNeeded() {
        do {
            let urls = try Self.store.loadAllEnabledBlockRules()
            guard !urls.isEmpty else {
                Self.logger.info("No enabled block rules, clearing filter")
                Self.currentFilter = nil
                Self.currentTag = nil
                return
            }

            let filter = BloomFilter.build(urls: urls, falsePositiveRate: 0.001)
            Self.currentFilter = filter
            Self.currentTag = filter.tag

            let dataSizeKB = filter.data.count / 1024
            Self.logger.info(
                "Built Bloom filter: \(urls.count) URLs, \(filter.bitCount) bits (\(dataSizeKB) KB), \(filter.hashCount) hashes"
            )
        } catch {
            Self.logger.error("Failed to build filter: \(error.localizedDescription)")
        }
    }

    // MARK: - List Change Observation

    /// Observe Darwin notifications from the app when filter lists change.
    private func observeListChanges() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(FilterListStore.listsDidChangeNotification as CFString)
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                FilterControlProvider.handleListChange()
            },
            name.rawValue,
            nil,
            .deliverImmediately
        )
        Self.logger.debug("Observing list change notifications")
    }

    /// Called when the app signals that filter lists have been updated.
    private static func handleListChange() {
        logger.info("List change notification received, rebuilding filter")
        do {
            let urls = try store.loadAllEnabledBlockRules()
            guard !urls.isEmpty else {
                currentFilter = nil
                currentTag = nil
                logger.info("No enabled block rules after change")
                return
            }
            let filter = BloomFilter.build(urls: urls, falsePositiveRate: 0.001)
            currentFilter = filter
            currentTag = filter.tag
            logger.info("Filter rebuilt: \(urls.count) URLs, tag: \(filter.tag)")
        } catch {
            logger.error("Failed to rebuild filter after change: \(error.localizedDescription)")
        }
    }
}
