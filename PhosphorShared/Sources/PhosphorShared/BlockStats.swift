import Foundation

/// Aggregate block statistics written by the extension and read by the app.
///
/// Since the NEURLFilter API provides no developer visibility into which URLs
/// are actually blocked, these counters are incremented from within the extension
/// when `fetchPrefilter` is called, and represent estimated activity rather than
/// confirmed blocks.
public struct BlockStats: Codable, Sendable {
    public var countsByCategory: [FilterCategory: Int]
    public var dailyCounts: [String: Int]  // ISO 8601 date string → count
    public var lastUpdated: Date?

    public init(
        countsByCategory: [FilterCategory: Int] = [:],
        dailyCounts: [String: Int] = [:],
        lastUpdated: Date? = nil
    ) {
        self.countsByCategory = countsByCategory
        self.dailyCounts = dailyCounts
        self.lastUpdated = lastUpdated
    }

    /// Total blocks across all categories.
    public var totalBlocks: Int {
        countsByCategory.values.reduce(0, +)
    }

    /// Blocks for today using the current calendar.
    public var todayBlocks: Int {
        dailyCounts[Self.dateKey(for: .now)] ?? 0
    }

    /// Returns the ISO 8601 date string key for a given date.
    public static func dateKey(for date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }

    /// Increment counters for a category.
    public mutating func increment(category: FilterCategory, count: Int = 1) {
        countsByCategory[category, default: 0] += count
        let key = Self.dateKey(for: .now)
        dailyCounts[key, default: 0] += count
        lastUpdated = .now
    }
}
