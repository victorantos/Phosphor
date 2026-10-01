import Foundation
import Testing
@testable import PhosphorShared

private func makeContainer() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func prefilterRebuildSavesFilterForEnabledLists() throws {
    let container = try makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }

    let lists = FilterListStore(containerURL: container)
    var enabled = FilterList(name: "Ads", category: .ads, source: .bundled, isEnabled: true)
    try lists.saveRules([FilterRule(url: "ads.example.com"), FilterRule(url: "www.ads.example.com")], for: &enabled)
    var disabled = FilterList(name: "Off", category: .trackers, source: .bundled, isEnabled: false)
    try lists.saveRules([FilterRule(url: "off.example.com")], for: &disabled)

    let store = PrefilterStore(containerURL: container)
    let metadata = try #require(try store.rebuild(from: lists))

    #expect(try store.loadMetadata() == metadata)
    let data = try store.loadData()
    #expect(data.count == (metadata.bitCount + 7) / 8)

    // The filter holds the enabled rule and Apple's test URL, each once and without `www.`.
    let expected = BloomFilter.build(
        urls: ["ads.example.com", "apple.com/url-filter-test"],
        falsePositiveRate: 0.001)
    #expect(expected.data == data)
    #expect(expected.tag == metadata.tag)
    #expect(metadata.urlCount == 2)
    #expect(expected.mightContain("ads.example.com"))
    #expect(expected.mightContain("apple.com/url-filter-test"))
}

@Test func prefilterRebuildRemovesFilterWhenNothingIsEnabled() throws {
    let container = try makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }

    let lists = FilterListStore(containerURL: container)
    var list = FilterList(name: "Ads", category: .ads, source: .bundled, isEnabled: true)
    try lists.saveRules([FilterRule(url: "ads.example.com")], for: &list)

    let store = PrefilterStore(containerURL: container)
    #expect(try store.rebuild(from: lists) != nil)

    list.isEnabled = false
    try lists.upsertList(list)
    #expect(try store.rebuild(from: lists) == nil)
    #expect(try store.loadMetadata() == nil)
}

@Test func prefilterMetadataIsNilBeforeFirstBuild() throws {
    let container = try makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }

    #expect(try PrefilterStore(containerURL: container).loadMetadata() == nil)
}

@Test func prefilterEntriesAreNormalizedToWhatTheSystemLooksUp() {
    let urls = ["www.Example.com", "example.com", "cdn.example.com", "www.example.com/path", "wwwx.example.com"]

    #expect(PrefilterStore.normalized(urls) == [
        "cdn.example.com",
        "example.com",
        "example.com/path",
        "wwwx.example.com",
    ])
}
