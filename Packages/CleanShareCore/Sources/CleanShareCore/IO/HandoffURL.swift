import Foundation

/// Builds and parses the URL the share extension uses to hand a completed job
/// back to the host app for re-sharing. See PLAN.md §6, §6.3.
///
/// Two equivalent forms are recognised:
/// - **Universal Link (default):** `https://cleanshare.dev/handoff?t=<token>` —
///   Apple's officially-supported way for an extension to launch its host app,
///   routed via the site's `apple-app-site-association`.
/// - **Custom scheme (fallback):** `cleanshare://handoff?t=<token>` — used when
///   the associated domain isn't resolvable (e.g. before the AASA propagates).
public extension URL {
    /// Host of the Universal Link form.
    static let handoffAssociatedDomain = "cleanshare.dev"
    /// Path of the Universal Link form (matched by the AASA `paths` entry).
    static let handoffPath = "/handoff"

    /// Universal Link handoff URL (default). Backed by `applinks:cleanshare.dev`.
    static func handoff(token: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = self.handoffAssociatedDomain
        components.path = self.handoffPath
        components.queryItems = [URLQueryItem(name: "t", value: token)]
        guard let url = components.url else {
            preconditionFailure("https handoff components are always a valid URL")
        }
        return url
    }

    /// Custom-scheme handoff URL (fallback). `cleanshare://handoff?t=<token>`.
    static func handoffCustomScheme(token: String) -> URL {
        var components = URLComponents()
        components.scheme = "cleanshare"
        components.host = "handoff"
        components.queryItems = [URLQueryItem(name: "t", value: token)]
        guard let url = components.url else {
            preconditionFailure("cleanshare://handoff components are always a valid URL")
        }
        return url
    }

    /// Identifiers shared between the share extension (which posts the
    /// "Cleaned & ready" local notification) and the host app (which routes a
    /// tap on that notification back into the share-sheet flow). Lives here so
    /// both targets see the same string constants without duplication.
    static let handoffNotificationCategory = "cs.readyToShare"
    static let handoffNotificationTokenKey = "cs.token"

    /// Extracts the job token from either handoff form, or `nil` for any other URL.
    ///
    /// The token is required to be a well-formed UUID. Job tokens are always
    /// `UUID().uuidString`, so this rejects nothing legitimate — but it prevents a
    /// crafted `…/handoff?t=../../…` from being used as a path component when the
    /// host app resolves `inbox/<token>/manifest.json` and later deletes that
    /// directory. Fails closed on any non-UUID input.
    static func handoffToken(from url: URL) -> String? {
        let isUniversalLink = url.scheme == "https"
            && url.host == self.handoffAssociatedDomain
            && url.path == self.handoffPath
        let isCustomScheme = url.scheme == "cleanshare" && url.host == "handoff"
        guard isUniversalLink || isCustomScheme else { return nil }
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "t" }?.value
        guard let value, UUID(uuidString: value) != nil else { return nil }
        return value
    }
}
