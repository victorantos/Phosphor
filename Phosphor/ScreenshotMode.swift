import Foundation

/// Opens one screen with the filter shown as running, for App Store screenshots taken
/// in the Simulator, which cannot run the filter. Launch with `PHOSPHOR_SCREENSHOT` set
/// to welcome, privacy, setup, dashboard, lists or settings. Debug builds only; release
/// builds always return nil.
enum ScreenshotMode {
    static var screen: String? {
        #if DEBUG
        ProcessInfo.processInfo.environment["PHOSPHOR_SCREENSHOT"]
        #else
        nil
        #endif
    }

    static var isActive: Bool { screen != nil }
}
