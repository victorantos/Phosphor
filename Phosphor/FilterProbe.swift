import Foundation
import NetworkExtension
import os

/// Asks the system URL filter for its verdict on a list of URLs and logs each one.
///
/// A diagnostic, run only when the app is launched with `PHOSPHOR_PROBE_URLS` set to a
/// comma-separated list of URLs.
enum FilterProbe {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "FilterProbe")

    static func runIfRequested() async {
        guard let list = ProcessInfo.processInfo.environment["PHOSPHOR_PROBE_URLS"] else { return }
        if #available(iOS 27, *) {
            let manager = NEURLFilterManager.shared
            try? await manager.loadFromPreferences()
            logger.info("PROBE parsing \(String(describing: manager.urlParsingConfiguration), privacy: .public)")
        }
        for text in list.split(separator: ",") {
            guard let url = URL(string: String(text)) else { continue }
            let verdict = await NEURLFilter.verdict(for: url)
            logger.info("PROBE \(url.absoluteString, privacy: .public) -> \(String(describing: verdict), privacy: .public)")
        }
        logger.info("PROBE done")
    }
}
