import CryptoKit
import Foundation

/// A Bloom filter compatible with Apple's `NEURLFilterPrefilter` requirements.
///
/// Uses **FNV-1a (32-bit)** and **MurmurHash3 (32-bit)** as the two base hash
/// functions, combined via **double hashing**: `h(i) = (fnv + i * murmur) mod bitCount`.
///
/// The system Punycodes URLs before checking, so callers should insert Punycode-encoded
/// URLs (plain ASCII domains are already valid Punycode).
public struct BloomFilter: Sendable {
    /// The raw bit array.
    public private(set) var data: Data
    /// Total number of bits in the filter.
    public let bitCount: Int
    /// Number of hash functions (k).
    public let hashCount: Int
    /// The seed used for MurmurHash3.
    public let murmurSeed: UInt32

    /// Create an empty Bloom filter with the given parameters.
    public init(bitCount: Int, hashCount: Int, murmurSeed: UInt32 = 0) {
        precondition(bitCount > 0, "bitCount must be positive")
        precondition(hashCount > 0, "hashCount must be positive")
        let byteCount = (bitCount + 7) / 8
        self.data = Data(count: byteCount)
        self.bitCount = bitCount
        self.hashCount = hashCount
        self.murmurSeed = murmurSeed
    }

    /// Insert a URL string into the filter.
    public mutating func insert(_ element: String) {
        let bytes = Array(element.utf8)
        let h1 = Self.fnv1a32(bytes)
        let h2 = Self.murmurHash3_32(bytes, seed: murmurSeed)

        for i in 0..<UInt32(hashCount) {
            let combined = h1 &+ i &* h2
            let bitIndex = Int(combined % UInt32(bitCount))
            setBit(at: bitIndex)
        }
    }

    /// Check if an element might be in the filter.
    /// Returns `false` for definite negatives, `true` for possible matches.
    public func mightContain(_ element: String) -> Bool {
        let bytes = Array(element.utf8)
        let h1 = Self.fnv1a32(bytes)
        let h2 = Self.murmurHash3_32(bytes, seed: murmurSeed)

        for i in 0..<UInt32(hashCount) {
            let combined = h1 &+ i &* h2
            let bitIndex = Int(combined % UInt32(bitCount))
            if !getBit(at: bitIndex) {
                return false
            }
        }
        return true
    }

    // MARK: - Bit manipulation

    private mutating func setBit(at index: Int) {
        let byteIndex = index / 8
        let bitOffset = UInt8(index % 8)
        data[byteIndex] |= (1 << bitOffset)
    }

    private func getBit(at index: Int) -> Bool {
        let byteIndex = index / 8
        let bitOffset = UInt8(index % 8)
        return (data[byteIndex] & (1 << bitOffset)) != 0
    }

    // MARK: - Hash functions

    /// FNV-1a 32-bit hash.
    static func fnv1a32(_ bytes: [UInt8]) -> UInt32 {
        var hash: UInt32 = 0x811c_9dc5 // FNV offset basis
        let prime: UInt32 = 0x0100_0193  // FNV prime
        for byte in bytes {
            hash ^= UInt32(byte)
            hash = hash &* prime
        }
        return hash
    }

    /// MurmurHash3 32-bit hash.
    static func murmurHash3_32(_ bytes: [UInt8], seed: UInt32) -> UInt32 {
        let c1: UInt32 = 0xcc9e_2d51
        let c2: UInt32 = 0x1b87_3593
        let len = bytes.count
        var h1 = seed

        // Body: process 4-byte blocks
        let nblocks = len / 4
        for i in 0..<nblocks {
            let offset = i * 4
            var k1: UInt32 = UInt32(bytes[offset])
            k1 |= UInt32(bytes[offset + 1]) << 8
            k1 |= UInt32(bytes[offset + 2]) << 16
            k1 |= UInt32(bytes[offset + 3]) << 24

            k1 = k1 &* c1
            k1 = (k1 << 15) | (k1 >> 17)
            k1 = k1 &* c2

            h1 ^= k1
            h1 = (h1 << 13) | (h1 >> 19)
            h1 = h1 &* 5 &+ 0xe654_6b64
        }

        // Tail: remaining bytes
        let tail = nblocks * 4
        var k1: UInt32 = 0
        switch len & 3 {
        case 3:
            k1 ^= UInt32(bytes[tail + 2]) << 16
            fallthrough
        case 2:
            k1 ^= UInt32(bytes[tail + 1]) << 8
            fallthrough
        case 1:
            k1 ^= UInt32(bytes[tail])
            k1 = k1 &* c1
            k1 = (k1 << 15) | (k1 >> 17)
            k1 = k1 &* c2
            h1 ^= k1
        default:
            break
        }

        // Finalization
        h1 ^= UInt32(len)
        h1 ^= h1 >> 16
        h1 = h1 &* 0x85eb_ca6b
        h1 ^= h1 >> 13
        h1 = h1 &* 0xc2b2_ae35
        h1 ^= h1 >> 16

        return h1
    }
}

// MARK: - Builder

extension BloomFilter {
    /// Compute optimal parameters and build a Bloom filter from a list of URL strings.
    ///
    /// - Parameters:
    ///   - urls: URL strings to insert.
    ///   - falsePositiveRate: Target false positive rate (default 0.01 = 1%).
    ///   - seed: MurmurHash3 seed.
    /// - Returns: A populated BloomFilter.
    public static func build(
        urls: [String],
        falsePositiveRate: Double = 0.01,
        seed: UInt32 = 0
    ) -> BloomFilter {
        let n = max(urls.count, 1)
        let m = optimalBitCount(itemCount: n, falsePositiveRate: falsePositiveRate)
        let k = optimalHashCount(bitCount: m, itemCount: n)

        var filter = BloomFilter(bitCount: m, hashCount: k, murmurSeed: seed)
        for url in urls {
            filter.insert(url)
        }
        return filter
    }

    /// Optimal number of bits: m = -(n * ln(p)) / (ln(2)^2)
    public static func optimalBitCount(itemCount n: Int, falsePositiveRate p: Double) -> Int {
        let m = -Double(n) * log(p) / (log(2.0) * log(2.0))
        return max(Int(m.rounded(.up)), 64)
    }

    /// Optimal number of hash functions: k = (m / n) * ln(2)
    public static func optimalHashCount(bitCount m: Int, itemCount n: Int) -> Int {
        let k = (Double(m) / Double(max(n, 1))) * log(2.0)
        return max(Int(k.rounded()), 1)
    }

    /// SHA-256 hex string of the filter data, usable as a prefilter tag.
    public var tag: String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
