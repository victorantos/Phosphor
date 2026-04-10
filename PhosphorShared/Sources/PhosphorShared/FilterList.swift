import Foundation

/// The origin of a filter list.
public enum FilterListSource: Codable, Sendable, Hashable {
    /// Bundled with the app.
    case bundled
    /// Fetched from a remote URL.
    case remote(URL)
    /// Manually created by the user.
    case manual
}

/// A named collection of filter rules.
public struct FilterList: Codable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var category: FilterCategory
    public var source: FilterListSource
    public var isEnabled: Bool
    public var lastUpdated: Date?
    public var ruleCount: Int
    /// Relative path within the shared container where the rules file is stored.
    /// Rules are stored separately from list metadata to keep memory low.
    public var rulesFilename: String

    public init(
        id: UUID = UUID(),
        name: String,
        category: FilterCategory,
        source: FilterListSource,
        isEnabled: Bool = true,
        lastUpdated: Date? = nil,
        ruleCount: Int = 0,
        rulesFilename: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.source = source
        self.isEnabled = isEnabled
        self.lastUpdated = lastUpdated
        self.ruleCount = ruleCount
        self.rulesFilename = rulesFilename ?? "\(id.uuidString).rules.json"
    }
}
