import Foundation

/// Connection details for the PIR server backing `NEURLFilterManager`.
enum PIRConfiguration {
    /// PIR server and Privacy Pass issuer share one host.
    static let serverURL = URL(string: "https://pir.phosphor.online")!

    /// Token used for Privacy Pass issuance, injected at build time from
    /// `Config/Secrets.xcconfig`. Nil when the build has no real token.
    static var authenticationToken: String? {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "PIRAuthenticationToken") as? String,
              !token.isEmpty,
              token != "replace-me"
        else { return nil }
        return token
    }
}
