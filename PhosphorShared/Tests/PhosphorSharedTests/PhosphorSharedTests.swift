import Foundation
import Testing
@testable import PhosphorShared

// MARK: - Constants

@Test func sharedConstantsExist() {
    #expect(PhosphorConstants.appGroupID == "group.com.example.phosphor")
    #expect(PhosphorConstants.filterExtensionBundleID == "com.example.phosphor.filter-extension")
}

// MARK: - FilterCategory

@Test func filterCategoryAllCases() {
    #expect(FilterCategory.allCases.count == 4)
}

@Test func filterCategoryDisplayNames() {
    #expect(FilterCategory.ads.displayName == "Ads")
    #expect(FilterCategory.trackers.displayName == "Trackers")
    #expect(FilterCategory.malware.displayName == "Malware")
    #expect(FilterCategory.adultContent.displayName == "Adult Content")
}

@Test func filterCategoryCodable() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    for category in FilterCategory.allCases {
        let data = try encoder.encode(category)
        let decoded = try decoder.decode(FilterCategory.self, from: data)
        #expect(decoded == category)
    }
}

// MARK: - FilterRule

@Test func filterRuleDefaults() {
    let rule = FilterRule(url: "https://ads.example.com")
    #expect(rule.action == .block)
    #expect(rule.url == "https://ads.example.com")
}

@Test func filterRuleCodableRoundTrip() throws {
    let rule = FilterRule(url: "https://tracker.example.com", action: .allow)
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let data = try encoder.encode(rule)
    let decoded = try decoder.decode(FilterRule.self, from: data)
    #expect(decoded.url == rule.url)
    #expect(decoded.action == rule.action)
    #expect(decoded.id == rule.id)
}

// MARK: - FilterList

@Test func filterListDefaults() {
    let list = FilterList(name: "Test", category: .ads, source: .bundled)
    #expect(list.isEnabled == true)
    #expect(list.ruleCount == 0)
    #expect(list.lastUpdated == nil)
    #expect(list.rulesFilename.hasSuffix(".rules.json"))
}

@Test func filterListCodableRoundTrip() throws {
    let list = FilterList(
        name: "EasyList",
        category: .ads,
        source: .remote(URL(string: "https://easylist.to/easylist.txt")!),
        isEnabled: true,
        lastUpdated: Date(timeIntervalSince1970: 1_700_000_000),
        ruleCount: 42
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let data = try encoder.encode(list)
    let decoded = try decoder.decode(FilterList.self, from: data)
    #expect(decoded.id == list.id)
    #expect(decoded.name == list.name)
    #expect(decoded.category == list.category)
    #expect(decoded.isEnabled == list.isEnabled)
    #expect(decoded.ruleCount == 42)
}

// MARK: - BlockStats

@Test func blockStatsIncrement() {
    var stats = BlockStats()
    stats.increment(category: .ads, count: 5)
    stats.increment(category: .trackers, count: 3)
    stats.increment(category: .ads, count: 2)
    #expect(stats.countsByCategory[.ads] == 7)
    #expect(stats.countsByCategory[.trackers] == 3)
    #expect(stats.totalBlocks == 10)
    #expect(stats.todayBlocks == 10)
}

@Test func blockStatsDateKey() {
    let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14
    let key = BlockStats.dateKey(for: date)
    #expect(key.contains("2023"))
}

// MARK: - FilterListStore

@Test func storeRoundTripLists() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let store = FilterListStore(containerURL: tempDir)
    let list = FilterList(name: "TestList", category: .malware, source: .bundled, ruleCount: 0)
    try store.saveLists([list])

    let loaded = try store.loadLists()
    #expect(loaded.count == 1)
    #expect(loaded[0].name == "TestList")
    #expect(loaded[0].category == .malware)
}

@Test func storeRoundTripRules() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let store = FilterListStore(containerURL: tempDir)
    var list = FilterList(name: "Ads", category: .ads, source: .bundled)
    let rules = [
        FilterRule(url: "https://ads.example.com"),
        FilterRule(url: "https://tracker.example.com", action: .allow),
    ]
    try store.saveRules(rules, for: &list)

    let loadedRules = try store.loadRules(for: list)
    #expect(loadedRules.count == 2)
    #expect(list.ruleCount == 2)
    #expect(list.lastUpdated != nil)
}

@Test func storeEnabledBlockRules() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let store = FilterListStore(containerURL: tempDir)

    var adsList = FilterList(name: "Ads", category: .ads, source: .bundled, isEnabled: true)
    try store.saveRules([
        FilterRule(url: "https://ads.example.com"),
        FilterRule(url: "https://good.example.com", action: .allow),
    ], for: &adsList)

    var disabledList = FilterList(name: "Disabled", category: .trackers, source: .bundled, isEnabled: false)
    try store.saveRules([
        FilterRule(url: "https://should-not-appear.example.com"),
    ], for: &disabledList)

    let blockURLs = try store.loadAllEnabledBlockRules()
    #expect(blockURLs.contains("https://ads.example.com"))
    #expect(!blockURLs.contains("https://good.example.com"))
    #expect(!blockURLs.contains("https://should-not-appear.example.com"))
}

@Test func storeRemoveList() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let store = FilterListStore(containerURL: tempDir)
    var list = FilterList(name: "ToRemove", category: .ads, source: .manual)
    try store.saveRules([FilterRule(url: "https://remove.me")], for: &list)

    try store.removeList(id: list.id)
    let remaining = try store.loadLists()
    #expect(remaining.isEmpty)
}

@Test func storeBlockStats() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let store = FilterListStore(containerURL: tempDir)
    var stats = BlockStats()
    stats.increment(category: .malware, count: 10)
    try store.saveStats(stats)

    let loaded = try store.loadStats()
    #expect(loaded.totalBlocks == 10)
    #expect(loaded.countsByCategory[.malware] == 10)
}
