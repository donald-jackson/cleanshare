import Foundation

/// Builds and parses the `cleanshare://handoff?t=<token>` URL the share
/// extension uses to hand a completed job back to the host app for re-sharing.
/// See PLAN.md §6.
public extension URL {
    static func handoff(token: String) -> URL {
        var components = URLComponents()
        components.scheme = "cleanshare"
        components.host = "handoff"
        components.queryItems = [URLQueryItem(name: "t", value: token)]
        guard let url = components.url else {
            preconditionFailure("cleanshare://handoff components are always a valid URL")
        }
        return url
    }

    static func handoffToken(from url: URL) -> String? {
        guard url.scheme == "cleanshare", url.host == "handoff" else { return nil }
        let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "t" }
        return token?.value
    }
}
