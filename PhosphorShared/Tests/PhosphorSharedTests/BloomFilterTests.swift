import Foundation
import Testing
@testable import PhosphorShared

// MARK: - Hash Functions

@Test func fnv1aKnownValues() {
    // FNV-1a 32-bit test vectors
    let empty = BloomFilter.fnv1a32([])
    #expect(empty == 0x811c_9dc5) // offset basis

    let a = BloomFilter.fnv1a32(Array("a".utf8))
    #expect(a == 0xe40c_292c)

    let foobar = BloomFilter.fnv1a32(Array("foobar".utf8))
    #expect(foobar == 0xbf9c_f968)
}

@Test func murmurHash3KnownValues() {
    // MurmurHash3 32-bit with seed 0
    let empty = BloomFilter.murmurHash3_32([], seed: 0)
    #expect(empty == 0) // empty input with seed 0 → 0

    // With different seeds, same input should produce different hashes
    let h1 = BloomFilter.murmurHash3_32(Array("test".utf8), seed: 0)
    let h2 = BloomFilter.murmurHash3_32(Array("test".utf8), seed: 42)
    #expect(h1 != h2)
}

@Test func murmurHash3Deterministic() {
    let bytes = Array("hello world".utf8)
    let h1 = BloomFilter.murmurHash3_32(bytes, seed: 123)
    let h2 = BloomFilter.murmurHash3_32(bytes, seed: 123)
    #expect(h1 == h2)
}

// MARK: - Bloom Filter

@Test func bloomFilterInsertAndQuery() {
    var filter = BloomFilter(bitCount: 1024, hashCount: 7, murmurSeed: 0)
    filter.insert("ads.example.com")
    filter.insert("tracker.example.com")

    #expect(filter.mightContain("ads.example.com"))
    #expect(filter.mightContain("tracker.example.com"))
}

@Test func bloomFilterNoFalseNegatives() {
    let urls = (0..<100).map { "test-domain-\($0).example.com" }
    var filter = BloomFilter(bitCount: 10000, hashCount: 7, murmurSeed: 0)
    for url in urls {
        filter.insert(url)
    }
    // Every inserted element must be found
    for url in urls {
        #expect(filter.mightContain(url), "False negative for: \(url)")
    }
}

@Test func bloomFilterFalsePositiveRate() {
    // Insert 1000 URLs, check 10000 non-inserted URLs
    let inserted = (0..<1000).map { "inserted-\($0).example.com" }
    let filter = BloomFilter.build(urls: inserted, falsePositiveRate: 0.01)

    var falsePositives = 0
    let testCount = 10_000
    for i in 0..<testCount {
        if filter.mightContain("not-inserted-\(i).example.com") {
            falsePositives += 1
        }
    }
    let rate = Double(falsePositives) / Double(testCount)
    // Allow 3x the target rate as margin (Bloom filters are probabilistic)
    #expect(rate < 0.03, "False positive rate too high: \(rate)")
}

@Test func bloomFilterBuilder() {
    let urls = ["ads.example.com", "tracker.example.com", "malware.example.com"]
    let filter = BloomFilter.build(urls: urls, falsePositiveRate: 0.01)

    #expect(filter.bitCount > 0)
    #expect(filter.hashCount > 0)
    #expect(filter.data.count == (filter.bitCount + 7) / 8)
    for url in urls {
        #expect(filter.mightContain(url))
    }
}

@Test func bloomFilterOptimalParameters() {
    let bits = BloomFilter.optimalBitCount(itemCount: 1000, falsePositiveRate: 0.01)
    let hashes = BloomFilter.optimalHashCount(bitCount: bits, itemCount: 1000)

    // For n=1000, p=0.01: m ≈ 9585, k ≈ 7
    #expect(bits > 9000 && bits < 10000)
    #expect(hashes >= 6 && hashes <= 8)
}

@Test func bloomFilterTag() {
    let urls = ["a.com", "b.com"]
    let filter = BloomFilter.build(urls: urls)

    let tag = filter.tag
    #expect(tag.count == 64) // SHA-256 hex = 64 chars
    // Same filter should produce same tag
    let filter2 = BloomFilter.build(urls: urls)
    #expect(filter2.tag == tag)
}

@Test func bloomFilterEmptyDoesNotCrash() {
    let filter = BloomFilter.build(urls: [])
    #expect(filter.bitCount >= 64)
    #expect(!filter.mightContain("anything"))
}
