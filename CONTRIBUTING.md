# Contributing to Phosphor

Thanks for your interest in contributing to Phosphor! This project is in its early stages and contributions are welcome.

## Getting Started

### Prerequisites

- macOS with Xcode 26+ installed
- iOS 26 SDK and simulator runtime
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An Apple Developer account (organization) for NetworkExtension entitlements

### Setup

```bash
git clone https://github.com/yourname/Phosphor.git
cd Phosphor
xcodegen generate
open Phosphor.xcodeproj
```

### Running Tests

```bash
cd PhosphorShared
swift test
```

## How to Contribute

### Reporting Bugs

- Use the [Bug Report](.github/ISSUE_TEMPLATE/bug_report.md) issue template
- Include your iOS version, device model, and steps to reproduce
- For security vulnerabilities, see [SECURITY.md](SECURITY.md) instead

### Suggesting Features

- Use the [Feature Request](.github/ISSUE_TEMPLATE/feature_request.md) issue template
- Explain the use case, not just the solution

### Submitting Code

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Run tests (`cd PhosphorShared && swift test`)
5. Regenerate the Xcode project (`xcodegen generate`)
6. Commit with a clear message following [Conventional Commits](https://www.conventionalcommits.org/)
7. Push and open a Pull Request

### Code Style

- **Swift 6** with strict concurrency
- **No force unwraps** — use proper error handling
- **No third-party dependencies** unless discussed and approved in an issue first
- Follow existing patterns — MV architecture, `@Observable` models, `FilterListStore` for persistence
- Add tests for new logic in `PhosphorShared`
- Use SF Symbols for icons, semantic colors for theming

### Areas Where Help is Needed

- **PIR server deployment** — Docker/container setup, deployment guides
- **Filter list parsing** — Support for more list formats (ABP filter syntax, etc.)
- **Localization** — Translations (the String Catalog is ready)
- **Testing on device** — Real-world testing with iOS 26 devices
- **App icon** — We need a proper app icon design

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the system works. Key things to know:

- The app **never sees URLs** — this is by design, not a limitation
- The extension runs under a **15 MB memory limit** — be careful with data structures
- Communication between app and extension is via **JSON files in the App Group container** + Darwin notifications
- The Bloom filter uses **FNV-1a + MurmurHash3** — don't change the hash functions, Apple requires them

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
