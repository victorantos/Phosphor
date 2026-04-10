import Foundation

/// Whether a rule blocks or allows a URL.
public enum RuleAction: String, Codable, Sendable {
    case block
    case allow
}

/// A single URL filtering rule.
///
/// Rules represent exact URLs or domains. The NEURLFilter system does not support
/// wildcards or regex — each entry is a literal URL that gets Punycode-encoded
/// before matching.
public struct FilterRule: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var url: String
    public var action: RuleAction

    public init(id: UUID = UUID(), url: String, action: RuleAction = .block) {
        self.id = id
        self.url = url
        self.action = action
    }
}
