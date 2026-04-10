# Phosphor Build Tools

## Bloom Filter Generation

The on-device prefilter is a Bloom filter using FNV-1a + MurmurHash3 (double hashing).

### Option 1: swift-bloom (community tool)

```bash
git clone https://github.com/ameshkov/swift-bloom
cd swift-bloom
swift run BloomFilterBuilder build \
  --input-path path/to/urls.txt \
  --false-positive-tolerance 0.001 \
  --output-path path/to/filter.plist
```

Input: newline-separated URL list. Output: `.plist` with binary Bloom filter data.

### Option 2: Custom builder

Build a custom tool using `NEURLFilterPrefilter`:
- Hash functions: 32-bit FNV-1a + 32-bit MurmurHash3 (double hashing)
- URLs must be Punycode-encoded before insertion
- The system generates all sub-URL permutations for matching

## PIR Database Processing

Use `PIRProcessDatabase` from [apple/swift-homomorphic-encryption](https://github.com/apple/swift-homomorphic-encryption):

```bash
PIRProcessDatabase config.json
```

See `PIRServer/README.md` for database format details.

## Filter List Conversion

Scripts to download and convert open filter lists to the URL format needed by the Bloom filter and PIR database will be added in Step 3.

Source lists:
- **Ads:** EasyList
- **Trackers:** EasyPrivacy, Peter Lowe's list
- **Malware:** StevenBlack/hosts (malware section)
- **Adult Content:** StevenBlack/hosts (adult section), oisd.nl NSFW
