import Foundation

/// Builds and parses the `cleanshare://handoff?t=<token>` URL the share
/// extension uses to hand a completed job back to the host app for re-sharing.
/// See PLAN.md §6.
public extension URL {
    static func handoff(token: String) -> URL {
        var c = URLComponents()
        c.scheme = "cleanshare"
        c.host = "handoff"
        c.queryItems = [URLQueryItem(name: "t", value: token)]
        return c.url!
    }

    static func handoffToken(from url: URL) -> String? {
        guard url.scheme == "cleanshare", url.host == "handoff" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "t" })?.value
    }
}
