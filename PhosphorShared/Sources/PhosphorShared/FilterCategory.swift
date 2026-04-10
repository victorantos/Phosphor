import Foundation

/// Categories of URL filter lists.
public enum FilterCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case ads
    case trackers
    case malware
    case adultContent

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ads: "Ads"
        case .trackers: "Trackers"
        case .malware: "Malware"
        case .adultContent: "Adult Content"
        }
    }

    public var systemImage: String {
        switch self {
        case .ads: "eye.slash"
        case .trackers: "shield.lefthalf.filled"
        case .malware: "exclamationmark.shield"
        case .adultContent: "hand.raised.fill"
        }
    }

    public var description: String {
        switch self {
        case .ads: "Block ads and banners across websites and apps."
        case .trackers: "Prevent cross-site tracking and fingerprinting."
        case .malware: "Block known malicious domains and phishing sites."
        case .adultContent: "Filter adult and explicit content domains."
        }
    }
}
