import Foundation
import NetworkExtension
import Observation
import os
import PhosphorShared

@Observable
@MainActor
final class SettingsViewModel {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "SettingsVM")
    private let store: FilterListStore

    var lists: [FilterList] = []
    var pauseEndDate: Date?
    /// Whether the system URL filter is actually running, as opposed to merely not paused.
    var filterIsRunning = false
    var updateFrequency: UpdateFrequency = .daily
    var errorMessage: String?
    var showExportShareSheet = false
    var exportURL: URL?

    enum UpdateFrequency: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case daily = "Daily"
        case twiceDaily = "Twice Daily"
        case weekly = "Weekly"

        var id: String { rawValue }

        var interval: TimeInterval? {
            switch self {
            case .manual: nil
            case .daily: 86400
            case .twiceDaily: 43200
            case .weekly: 604800
            }
        }
    }

    init(store: FilterListStore = FilterListStore()) {
        self.store = store
        if let raw = PhosphorConstants.sharedDefaults?.string(forKey: "updateFrequency"),
           let freq = UpdateFrequency(rawValue: raw) {
            updateFrequency = freq
        }
        if let pauseEnd = FilterPause.endDate, pauseEnd > .now {
            pauseEndDate = pauseEnd
        }
    }

    // MARK: - Load

    func load() {
        do {
            lists = try store.loadLists()
        } catch {
            Self.logger.error("Failed to load lists: \(error.localizedDescription)")
        }
        Task { await loadFilterStatus() }
    }

    func loadFilterStatus() async {
        if ScreenshotMode.isActive { filterIsRunning = true; return }
        let manager = NEURLFilterManager.shared
        do {
            try await manager.loadFromPreferences()
            let status = await manager.status
            filterIsRunning = manager.isEnabled && status == .running
        } catch {
            filterIsRunning = false
        }
    }

    func observeFilterStatus() async {
        if ScreenshotMode.isActive { return }
        let manager = NEURLFilterManager.shared
        for await status in manager.handleStatusChange() {
            filterIsRunning = manager.isEnabled && status == .running
        }
    }

    // MARK: - Category Toggles

    func isEnabled(_ category: FilterCategory) -> Bool {
        lists.filter { $0.category == category }.contains(where: \.isEnabled)
    }

    func toggleCategory(_ category: FilterCategory) {
        let categoryLists = lists.filter { $0.category == category }
        let anyEnabled = categoryLists.contains(where: \.isEnabled)
        for list in categoryLists {
            var updated = list
            updated.isEnabled = !anyEnabled
            try? store.upsertList(updated)
            FilterRefresher.listsChanged()
        }
        load()
    }

    // MARK: - Pause

    var isPaused: Bool {
        guard let end = pauseEndDate else { return false }
        return end > .now
    }

    var pauseTimeRemaining: String? {
        guard let end = pauseEndDate, end > .now else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Resumes \(formatter.localizedString(for: end, relativeTo: .now))"
    }

    func pause(duration: PauseDuration) {
        let end: Date
        switch duration {
        case .fifteenMinutes: end = .now.addingTimeInterval(15 * 60)
        case .oneHour: end = .now.addingTimeInterval(3600)
        case .untilTomorrow:
            end = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        }
        pauseEndDate = end
        Task {
            do {
                try await FilterPause.pause(until: end)
            } catch {
                pauseEndDate = nil
                errorMessage = "Could not pause filtering: \(error.localizedDescription)"
            }
            await loadFilterStatus()
        }
    }

    func unpause() {
        pauseEndDate = nil
        Task {
            do {
                try await FilterPause.resume()
            } catch {
                errorMessage = "Could not resume filtering: \(error.localizedDescription)"
            }
            await loadFilterStatus()
        }
    }

    enum PauseDuration: String, CaseIterable {
        case fifteenMinutes = "15 Minutes"
        case oneHour = "1 Hour"
        case untilTomorrow = "Until Tomorrow"
    }

    // MARK: - Update Frequency

    func setUpdateFrequency(_ freq: UpdateFrequency) {
        updateFrequency = freq
        PhosphorConstants.sharedDefaults?.set(freq.rawValue, forKey: "updateFrequency")
    }

    // MARK: - Export

    func exportConfig() {
        do {
            let config = ExportedConfig(
                lists: lists,
                updateFrequency: updateFrequency.rawValue,
                exportDate: .now
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("phosphor-config.json")
            try data.write(to: url)
            exportURL = url
            showExportShareSheet = true
            Self.logger.info("Config exported")
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Import

    func importConfig(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(ExportedConfig.self, from: data)
            try store.saveLists(config.lists)
            FilterRefresher.listsChanged()
            if let freq = UpdateFrequency(rawValue: config.updateFrequency) {
                setUpdateFrequency(freq)
            }
            load()
            Self.logger.info("Config imported: \(config.lists.count) lists")
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Reset

    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
}

struct ExportedConfig: Codable {
    let lists: [FilterList]
    let updateFrequency: String
    let exportDate: Date
}
