//
//  HomeRoute.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where a URL zContainer was opened with goes. HomeRouter reads it with
/// `init(url:)` and sends it on; the root view can also follow it, for example
/// by showing the screen it concerns.
enum HomeRoute: Equatable {
    /// Brings up zContainer's own screens and nothing else, as
    /// `livecontainer-launch?bundle-name=ui` asks, or an app link that names
    /// nothing to do.
    case home

    /// Installs, launches or opens something in an app, which
    /// AppLaunchCoordinator does.
    case app(AppLink)

    /// Adds an app source, from `source?url=<source URL>`. It waits in
    /// HomeRouter until the Sources screen takes it.
    case source(String)

    /// Stores a signing certificate, from `certificate?cert=&password=`. It
    /// waits in HomeRouter until the certificate import takes it.
    case certificate(CertificateLink)

    /// Reads the route from a URL zContainer was opened with, either a link
    /// with its own scheme or a file it was asked to open. Returns nil for URLs
    /// zContainer doesn't handle.
    init?(url: URL) {
        if let link = AppLink(url: url) {
            self = .app(link)
            return
        }
        switch url.host?.lowercased() {
        case "livecontainer-launch", "install", "open-web-page", "open-url":
            self = .home
        case "source":
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let sourceURL = queryItems.last(where: { $0.name == "url" && $0.value != nil })?.value else {
                return nil
            }
            self = .source(sourceURL)
        case "certificate":
            guard let link = CertificateLink(url: url) else {
                return nil
            }
            self = .certificate(link)
        default:
            return nil
        }
    }
}
