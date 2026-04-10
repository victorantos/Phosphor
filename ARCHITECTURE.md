# Architecture: How Phosphor Filters URLs Without Seeing Them

This document explains how Apple's `NEURLFilterManager` API works under the hood, and how Phosphor uses it to provide system-wide URL filtering while preserving user privacy. If you're new to Private Information Retrieval or homomorphic encryption, this is the right place to start.

## The Problem

Traditional content blockers face a fundamental tension: to block a URL, something needs to *see* the URL. DNS-based blockers see every domain you resolve. VPN-based blockers see every connection. Even on-device blockers that process rules locally still have code running in your process that could, in theory, exfiltrate browsing data.

Apple's answer with iOS 26 is: **what if the filter could work without anyone — not even the filtering app — ever seeing the URL?**

## The Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        User's iPhone                                │
│                                                                     │
│  Safari / App                                                       │
│      │                                                              │
│      ▼                                                              │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │              iOS URL Filter System                       │        │
│  │                                                         │        │
│  │  1. Generate sub-URLs from the request                  │        │
│  │  2. Check each against the Bloom filter                 │        │
│  │     ├── No match → ALLOW (zero network traffic)         │        │
│  │     └── Match →                                         │        │
│  │  3. Encrypt a PIR query (homomorphic encryption)        │        │
│  │  4. Send through OHTTP relay                            │        │
│  │  5. Decrypt response → BLOCK or ALLOW                   │        │
│  └──────────────────────────┬──────────────────────────────┘        │
│                             │                                       │
│  ┌──────────────────────────┴──────────────────────────────┐        │
│  │         Phosphor Filter Extension                        │        │
│  │         (NEURLFilterControlProvider)                      │        │
│  │                                                         │        │
│  │  - Provides the Bloom filter on request                 │        │
│  │  - Reads enabled rules from App Group container         │        │
│  │  - Rebuilds filter when lists change                    │        │
│  └─────────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    Encrypted PIR query
                              │
                              ▼
                 ┌────────────────────────┐
                 │   Apple OHTTP Relay    │
                 │                        │
                 │ Knows: user's IP       │
                 │ Doesn't know: query    │
                 └───────────┬────────────┘
                             │
                    Encrypted, IP-stripped
                             │
                             ▼
                 ┌────────────────────────┐
                 │   Your PIR Server      │
                 │   + OHTTP Gateway      │
                 │                        │
                 │ Knows: encrypted query │
                 │ Doesn't know: user IP, │
                 │   actual URL queried   │
                 └────────────────────────┘
```

## Layer 1: The Bloom Filter (On-Device)

A [Bloom filter](https://en.wikipedia.org/wiki/Bloom_filter) is a probabilistic data structure that can tell you with certainty that an element is *not* in a set, but can only say an element *might* be in the set (false positives are possible, false negatives are not).

For URL filtering, this is perfect:
- **Not in filter → Allow immediately.** No network request, no latency, no privacy cost. This handles ~99.9% of URLs.
- **Might be in filter → Need to check.** This triggers a PIR query (see below).

### How Phosphor Builds the Bloom Filter

Apple specifies the hash functions: **FNV-1a (32-bit)** and **MurmurHash3 (32-bit)** combined via **double hashing**:

```
h(i) = (FNV-1a(url) + i × MurmurHash3(url)) mod bitCount
```

Where `i` ranges from `0` to `hashCount - 1`. Each hash sets one bit in the filter. To check membership, all `hashCount` bits must be set.

Phosphor computes optimal parameters from the URL count and target false positive rate (0.1%):
- **Bit count:** `m = -(n × ln(p)) / (ln(2)²)` — for 123K URLs, ~1.8M bits (~220 KB)
- **Hash count:** `k = (m / n) × ln(2)` — typically 10 hash functions

The extension provides this Bloom filter to the system via `fetchPrefilter()`. The system caches it and re-requests periodically (default: every 24 hours).

### Sub-URL Generation

Before checking the Bloom filter, the system generates all sub-URL permutations. For example, `https://www.example.com/a/b?id=1#frag` produces entries like:
- `https://www.example.com/a/b?id=1#frag`
- `https://www.example.com/a/b?id=1`
- `https://www.example.com/a/b`
- `https://www.example.com/a`
- `https://www.example.com`
- `https://example.com/a/b`
- `https://example.com`
- (and more variants with/without trailing slashes)

This means adding `example.com` to the block list effectively blocks all URLs under that domain.

## Layer 2: Private Information Retrieval (PIR)

When the Bloom filter says "maybe," the system needs to confirm. But it can't just send the URL to a server — that would defeat the privacy model.

**Private Information Retrieval** lets a client query a database without the server learning which entry was queried. Apple uses a PIR scheme based on the **BFV homomorphic encryption** scheme (Brakerski-Fan-Vercauteren), built on Ring Learning With Errors (RLWE).

### How It Works (Simplified)

1. The PIR server hosts a database: `{URL₁ → 1, URL₂ → 1, ...}` (presence-only)
2. The client wants to know: "Is URL_x in this database?"
3. The client **encrypts** a query vector that, when multiplied against the database, extracts just the entry for URL_x
4. The server performs the multiplication **on the encrypted data** (homomorphic encryption allows computation on ciphertexts)
5. The server returns the **encrypted result**
6. The client **decrypts** the result to get `1` (blocked) or `0` (not blocked)

The server performed the computation without ever decrypting the query or the result. It knows *something* was queried but not *what*.

### Apple's Implementation

Apple provides the PIR server implementation at [apple/pir-service-example](https://github.com/apple/pir-service-example), built with:
- [swift-homomorphic-encryption](https://github.com/apple/swift-homomorphic-encryption) — the BFV scheme
- Hummingbird HTTP framework
- Protocol Buffers for serialization

The database is processed offline with `PIRProcessDatabase`, which:
1. Takes the URL list as a keyword database (protobuf format)
2. Applies cuckoo hashing for efficient PIR lookup
3. Shards the database for parallelism
4. Outputs encrypted database files + PIR parameters

## Layer 3: Privacy Pass (Anonymous Authentication)

The PIR server needs to authenticate requests (to prevent abuse) but can't use cookies or tokens that identify users. **Privacy Pass** (RFC 9578) solves this:

1. The user's device obtains blind-signed tokens from the Privacy Pass issuer
2. Each PIR query redeems one token
3. The server can verify the token is valid but cannot link it to the issuance event

This prevents the server from correlating requests across time while still preventing unauthorized access.

## Layer 4: OHTTP Relay (Network Anonymity)

Even with PIR and Privacy Pass, the server would see the client's IP address. **Oblivious HTTP** (OHTTP) adds network-level anonymity:

```
Client ──encrypted──→ Apple Relay ──encrypted──→ OHTTP Gateway ──plaintext──→ PIR Server
         (Apple sees IP,            (IP stripped,
          not content)               content visible)
```

- **Apple's relay** sees the user's IP but cannot read the encrypted request
- **Your OHTTP gateway** can read the request but doesn't know the user's IP
- **Neither party sees both**

Apple hosts the OHTTP relay. You run the gateway (Cloudflare provides [an open-source implementation](https://github.com/cloudflare/privacy-gateway-server-go)).

## Phosphor's Architecture

### Three Targets

1. **Phosphor** (main app) — SwiftUI app with onboarding, filter management, dashboard, settings
2. **PhosphorFilterExtension** — `NEURLFilterControlProvider` that serves the Bloom filter
3. **PhosphorShared** — Swift package with models, Bloom filter builder, persistence

### Data Flow

```
App                          Shared Container              Extension
 │                               │                            │
 │  ┌─ FilterListStore ──────── JSON files ── FilterListStore ─┐
 │  │                            │                            │ │
 │  │  Save/toggle lists   filter-lists.json   Load rules     │ │
 │  │  Save rules          rules/*.json        Build Bloom    │ │
 │  │                            │              filter        │ │
 │  └─ Darwin notification ──────┼──── triggers reload ───────┘ │
 │                               │                              │
 │  Read stats             block-stats.json    Write stats      │
```

The app and extension communicate through the App Group shared container:
- **List metadata** (`filter-lists.json`) — which lists exist, enabled state, rule counts
- **Rule files** (`rules/*.json`) — separate file per list to limit memory
- **Block stats** (`block-stats.json`) — aggregate counters
- **Darwin notifications** — signal the extension to reload when lists change

### Memory Management

The extension runs under iOS's 15 MB memory limit. Phosphor manages this by:
- Storing rules in separate files per list (only enabled lists are loaded)
- Building the Bloom filter once, caching it in memory
- Using `NEURLFilterPrefilter.PrefilterData.smallFilter(Data)` for filters under a few MB, or `.temporaryFilepath(URL)` for larger ones

## Limitations

- **Block-only** — No URL modification, redirection, or custom error pages
- **Exact matching** — No wildcards or regex; the system generates sub-URL permutations instead
- **No developer feedback** — The app cannot see which URLs were blocked or even queried
- **PIR server required** — Full URL verification needs a server; the Bloom filter alone has false positives
- **45-minute minimum** update interval for the Bloom filter
- **OHTTP approval required** for App Store distribution (development builds are exempt)

## Further Reading

- [WWDC25 Session 234: Filter and tunnel network traffic with NetworkExtension](https://developer.apple.com/videos/play/wwdc2025/234/)
- [NEURLFilterManager Documentation](https://developer.apple.com/documentation/networkextension/neurlfiltermanager)
- [apple/swift-homomorphic-encryption](https://github.com/apple/swift-homomorphic-encryption)
- [apple/pir-service-example](https://github.com/apple/pir-service-example)
- [RFC 9578: Privacy Pass Issuance Protocols](https://www.rfc-editor.org/rfc/rfc9578)
- [Oblivious HTTP (OHTTP)](https://www.ietf.org/archive/id/draft-ietf-ohai-ohttp-08.html)
