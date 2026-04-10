# Security Policy

## Threat Model

Phosphor's security properties are largely inherited from Apple's `NEURLFilterManager` architecture. Here's what the system protects against and what remains in scope.

### What the Architecture Protects

| Threat | Mitigation |
|--------|------------|
| **App sees user's browsing history** | The app never receives URLs. The system checks URLs against the Bloom filter and PIR server directly. The extension only provides the filter data. |
| **PIR server learns queried URLs** | Homomorphic encryption (BFV scheme) means the server processes queries without decrypting them. |
| **PIR server learns user identity** | Privacy Pass provides anonymous authentication. OHTTP relay (Apple-hosted) strips the user's IP address. |
| **Apple learns queried URLs** | Apple's OHTTP relay only sees encrypted traffic and the user's IP — it cannot read query content. |
| **Network observer sees queries** | All PIR traffic is encrypted end-to-end and routed through OHTTP. |
| **Filter list tampering in transit** | Remote lists are fetched over HTTPS. Bundled lists are signed as part of the app binary. |

### What Remains in Scope

| Risk | Description | Mitigation |
|------|-------------|------------|
| **PIR server + Privacy Pass issuer collusion** | Both are operated by the app developer. A malicious developer could theoretically correlate token issuance with PIR queries. | This is a known limitation of the architecture. Phosphor is open source — you can audit the server and self-host. |
| **Bloom filter false positives** | A crafted Bloom filter could force all URLs through PIR, increasing the server's ability to infer browsing patterns (via timing and volume). | Phosphor uses standard optimal parameters with 0.1% false positive rate. The filter is deterministically built from the published block list. |
| **Malicious filter lists** | A custom remote list could block legitimate sites (denial of service) or fail to block malicious sites. | Users control which lists are enabled. Bundled lists use well-known, community-maintained sources. |
| **Extension memory exhaustion** | A very large filter list could exceed the 15 MB extension memory limit, crashing the extension. | Rules are stored in separate files per list. The Bloom filter is compact (~220 KB for 123K URLs). |
| **Local data access** | Another app with the same App Group (impossible without your signing identity) or a jailbroken device could read the shared container. | The shared container only stores filter list metadata, domain lists, and aggregate stats — no browsing data. |

### Out of Scope

- **Device compromise** — If the device is jailbroken or compromised, all bets are off. This is not specific to Phosphor.
- **Side-channel attacks on PIR** — Timing attacks on the PIR server are theoretically possible but impractical at scale. Apple's BFV implementation includes standard countermeasures.
- **DNS-level filtering bypass** — Phosphor filters at the URL level, not DNS. Apps using custom DNS resolvers or IP-direct connections may bypass filtering in some cases.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in Phosphor, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email **security@example.com** (replace with your actual contact) with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
3. You will receive an acknowledgment within **48 hours**
4. We will work with you to understand and address the issue before any public disclosure
5. We aim to release a fix within **7 days** of confirming the vulnerability

### Scope

The following are in scope for security reports:
- Vulnerabilities in Phosphor's Swift code (app, extension, shared package)
- Privacy leaks (the app or extension accessing or transmitting URL data it shouldn't)
- Filter bypass techniques specific to Phosphor's implementation
- Insecure data storage in the shared container

The following are **out of scope**:
- Vulnerabilities in Apple's `NEURLFilterManager` implementation (report to Apple)
- Vulnerabilities in upstream filter lists (report to list maintainers)
- Vulnerabilities in the PIR server reference implementation (report to Apple via the swift-homomorphic-encryption repo)
- Social engineering or phishing attacks

## Security Design Principles

1. **Least privilege** — The extension only reads filter data; it never sees URLs. The app never sees browsing activity.
2. **No telemetry** — Zero analytics, crash reporting, or network calls beyond filter list updates and PIR queries.
3. **Minimal data** — The shared container stores only domain lists and aggregate counters. No PII, no browsing history, no timestamps of individual events.
4. **Open source** — All code is auditable. The PIR server can be self-hosted.
5. **Fail open** — By default (`shouldFailClosed = false`), if PIR fails, URLs are allowed rather than blocked. Availability over false security.
