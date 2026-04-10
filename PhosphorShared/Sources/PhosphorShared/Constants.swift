import Foundation

public enum PhosphorConstants {
    /// App Group identifier shared between the main app and the filter extension.
    public static let appGroupID = "group.com.nestclaw.phosphor"

    /// Suite name for shared UserDefaults.
    public static let suiteName = appGroupID

    /// Bundle identifier for the filter extension.
    public static let filterExtensionBundleID = "com.nestclaw.phosphor.filter-extension"

    /// Shared UserDefaults instance for cross-target communication.
    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// URL for the shared App Group container directory.
    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
}
