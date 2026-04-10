# Phosphor PIR Server

The `NEURLFilterManager` API requires a PIR (Private Information Retrieval) server that the system queries using homomorphic encryption when a URL matches the on-device Bloom filter prefilter.

## Architecture

```
Device (Bloom filter) → Apple OHTTP Relay → Your OHTTP Gateway → Your PIR Server
```

## Reference Implementation

Apple provides an official reference PIR server:

- **Repo:** [apple/pir-service-example](https://github.com/apple/pir-service-example)
- **Language:** Swift 6 (Hummingbird HTTP framework)
- **Crypto:** [apple/swift-homomorphic-encryption](https://github.com/apple/swift-homomorphic-encryption)

This same server implementation supports both Live Caller ID Lookup and NEURLFilter use cases.

## Required Components

1. **PIR Server** — Hosts the encrypted URL database, handles PIR queries
2. **Privacy Pass Issuer** — Issues anonymous authentication tokens (included in pir-service-example)
3. **OHTTP Gateway** — Decrypts relay traffic (use [cloudflare/privacy-gateway-server-go](https://github.com/cloudflare/privacy-gateway-server-go) or similar)

## Database Format

- **Keys:** URL strings (Punycode-encoded)
- **Values:** Integer `1` (presence-only database)
- **Processing:** Use `PIRProcessDatabase` tool from swift-homomorphic-encryption
- **Use case identifier:** `com.example.phosphor.url.filtering`

## Setup Steps (deferred to later build steps)

1. Clone `apple/pir-service-example`
2. Prepare URL list from filter lists (Ads, Trackers, Malware, Adult Content)
3. Process database with `PIRProcessDatabase`
4. Configure and deploy PIR server + Privacy Pass issuer
5. Set up OHTTP gateway
6. Configure `NEURLFilterManager` in the app with server URLs

## Notes

- Development-signed builds are exempt from OHTTP relay approval
- App Store distribution requires Apple approval for the OHTTP relay
- The PIR server never sees which URLs users are querying (homomorphic encryption)
