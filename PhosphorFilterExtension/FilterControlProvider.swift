import ExtensionFoundation
import NetworkExtension
import os

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

    func fetchPrefilter(existingPrefilterTag: String?) async throws -> NEURLFilterPrefilter? {
        logger.info("fetchPrefilter called")
        return nil
    }
}
