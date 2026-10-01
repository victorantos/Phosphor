import Foundation
import NetworkExtension
import Observation
import os
import PhosphorShared

@Observable
@MainActor
final class DashboardViewModel {
    private static let logger = Logger(subsystem: "com.nestclaw.phosphor", category: "DashboardVM")
    private let store: FilterListStore

    var stats = BlockStats()
    var enabledListCount = 0
    var totalRuleCount = 0
    var filterIsEnabled = false
    var filterStatus: String = "Unknown"

    /// When the app first saw the filter starting, kept across launches so the
    /// dashboard can say how long it has been. Cleared once it runs or is switched off.
    var startingSince: Date? {
        get { UserDefaults.standard.object(forKey: Self.startingSinceKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.startingSinceKey) }
    }
    private static let startingSinceKey = "filterStartingSince"

    init(store: FilterListStore = FilterListStore()) {
        self.store = store
    }

    // MARK: - Load

    func load() {
        do {
            stats = try store.loadStats()
            let lists = try store.loadLists()
            let enabled = lists.filter(\.isEnabled)
            enabledListCount = enabled.count
            totalRuleCount = enabled.reduce(0) { $0 + $1.ruleCount }
        } catch {
            Self.logger.error("Failed to load dashboard data: \(error.localizedDescription)")
        }
        Task { await loadFilterStatus() }
    }

    func loadFilterStatus() async {
        do {
            let manager = NEURLFilterManager.shared
            try await manager.loadFromPreferences()
            filterIsEnabled = manager.isEnabled
            let status = await manager.status
            apply(status)
            let reason = await manager.lastDisconnectError
            Self.logger.info("Filter status: \(self.filterStatus, privacy: .public), enabled: \(self.filterIsEnabled), last error: \(reason.map { String(describing: $0) } ?? "none", privacy: .public), server: \(manager.pirServerURL?.host() ?? "nil", privacy: .public)")
        } catch {
            Self.logger.error("Failed to load filter status: \(error.localizedDescription, privacy: .public)")
            filterIsEnabled = false
            filterStatus = "Not Configured"
        }
    }

    /// Keeps the status current while the dashboard is on screen. The filter can
    /// take a while to go from starting to running, so one read at load is not enough.
    func observeFilterStatus() async {
        for await status in NEURLFilterManager.shared.handleStatusChange() {
            apply(status)
            filterIsEnabled = NEURLFilterManager.shared.isEnabled
            Self.logger.info("Filter status changed: \(self.filterStatus, privacy: .public)")
        }
    }

    private func apply(_ status: NEURLFilterManager.Status) {
        // A starting filter can read `stopped` or `invalid` between attempts, so only
        // running or a switched-off filter ends the wait.
        if status == .running || !NEURLFilterManager.shared.isEnabled {
            if startingSince != nil { startingSince = nil }
        } else if startingSince == nil {
            // Switched on but not running, whichever status it reads: start the clock,
            // so a filter stuck at `stopped` still gets the help after 10 minutes.
            startingSince = .now
        }
        if status != .running, SubscriptionGate.isPausedForSubscription {
            filterStatus = "Paused"
            return
        }
        switch status {
        case .running: filterStatus = "Running"
        case .starting: filterStatus = "Starting"
        case .stopped: filterStatus = FilterPause.isActive ? "Paused" : "Stopped"
        case .stopping: filterStatus = "Stopping"
        case .invalid: filterStatus = "Not Configured"
        @unknown default: filterStatus = "Unknown"
        }
    }

    // MARK: - Derived Data

    var todayBlocks: Int { stats.todayBlocks }
    var totalBlocks: Int { stats.totalBlocks }

    /// Blocks in the last 7 days.
    var weekBlocks: Int {
        blocksInRange(days: 7)
    }

    /// Blocks in the last 30 days.
    var monthBlocks: Int {
        blocksInRange(days: 30)
    }

    private func blocksInRange(days: Int) -> Int {
        let calendar = Calendar.current
        var total = 0
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            let key = BlockStats.dateKey(for: date)
            total += stats.dailyCounts[key] ?? 0
        }
        return total
    }

    // MARK: - Category Chart Data

    struct CategoryDataPoint: Identifiable {
        let id = UUID()
        let category: FilterCategory
        let count: Int
    }

    var categoryBreakdown: [CategoryDataPoint] {
        FilterCategory.allCases.compactMap { cat in
            let count = stats.countsByCategory[cat] ?? 0
            guard count > 0 else { return nil }
            return CategoryDataPoint(category: cat, count: count)
        }
    }

    // MARK: - Trend Chart Data

    struct DailyDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    /// Daily block counts for the last N days, ordered chronologically.
    func dailyTrend(days: Int = 14) -> [DailyDataPoint] {
        let calendar = Calendar.current
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            let key = BlockStats.dateKey(for: date)
            let count = stats.dailyCounts[key] ?? 0
            return DailyDataPoint(date: date, count: count)
        }
    }

    // MARK: - Demo Data (for previews and empty state)

    static func withSampleData() -> DashboardViewModel {
        let vm = DashboardViewModel()
        var stats = BlockStats()
        let calendar = Calendar.current
        for offset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            let key = BlockStats.dateKey(for: date)
            let count = Int.random(in: 20...300)
            stats.dailyCounts[key] = count
        }
        stats.countsByCategory = [
            .ads: 1842,
            .trackers: 956,
            .malware: 23,
            .adultContent: 67,
        ]
        vm.stats = stats
        vm.enabledListCount = 4
        vm.totalRuleCount = 123_211
        return vm
    }
}
