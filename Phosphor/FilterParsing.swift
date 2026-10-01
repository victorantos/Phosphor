import NetworkExtension
import os

/// How the system breaks a URL into the forms it looks up.
///
/// The lists name parent domains such as `doubleclick.net`, while ads are served from
/// hosts like `ad.doubleclick.net`. iOS 26 walks up the domain hierarchy on its own.
/// iOS 27 does not for a configuration saved without a parsing configuration, and then
/// looks up only the exact host, so the configuration is set explicitly.
enum FilterParsing {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "FilterParsing")

    /// Sets the parsing configuration on `manager` if it differs. Returns whether it
    /// changed, in which case the caller must save the manager.
    @discardableResult
    static func apply(to manager: NEURLFilterManager) -> Bool {
        guard #available(iOS 27, *) else { return false }
        // Apple's defaults: drop the scheme and a leading `www.`, walk the domain and
        // path hierarchies. `a.b.example.com/x/y` is looked up as `example.com`,
        // `b.example.com/x`, `a.b.example.com/x/y` and the other combinations, which
        // covers both the host-only entries and the onboarding test URL with its path.
        let desired = NEURLFilterManager.ParsingConfiguration()
        guard !matches(manager.urlParsingConfiguration, desired) else { return false }
        manager.urlParsingConfiguration = desired
        return true
    }

    /// Call when the app becomes active. Existing installs were configured without a
    /// parsing configuration and keep matching exact hosts until it is saved.
    static func updateSavedConfiguration() async {
        guard #available(iOS 27, *) else { return }
        let manager = NEURLFilterManager.shared
        do {
            try await manager.loadFromPreferences()
            guard manager.pirServerURL != nil, apply(to: manager) else { return }
            try await manager.saveToPreferences()
            logger.info("Saved URL parsing configuration")
        } catch {
            logger.error("Saving URL parsing configuration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @available(iOS 27, *)
    private static func matches(
        _ a: NEURLFilterManager.ParsingConfiguration,
        _ b: NEURLFilterManager.ParsingConfiguration
    ) -> Bool {
        a.excludeScheme == b.excludeScheme
            && a.domain.excluded == b.domain.excluded
            && a.domain.stripWWW == b.domain.stripWWW
            && a.domain.levels == b.domain.levels
            && a.domain.enumerateHierarchy == b.domain.enumerateHierarchy
            && a.path.excluded == b.path.excluded
            && a.path.segments == b.path.segments
            && a.path.enumerateHierarchy == b.path.enumerateHierarchy
            && a.query.excluded == b.query.excluded
            && a.query.parameters == b.query.parameters
            && a.excludeFragment == b.excludeFragment
            && a.excludeIntermediates == b.excludeIntermediates
            && a.caseSensitive == b.caseSensitive
    }
}
