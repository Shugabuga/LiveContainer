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

    /// Stores a signing certificate, from `certificate?cert=&password=`, once
    /// the person says to use it.
    case certificate(CertificateLink)

    /// Stores the signing certificate in a .p12 (or .pfx) file zContainer was
    /// asked to open, once the person types its password and says to use it.
    case certificateFile(URL)

    /// Takes what Zeus left in the app group the two apps share, from
    /// `zeus-request?id=<UUID>&id=<UUID>`: apps to install or update, or
    /// Zeus's certificate. The link only names the requests, by id; what they
    /// send is read from the group.
    case zeusRequests([UUID])

    /// Reads the route from a URL zContainer was opened with, either a link
    /// with its own scheme or a file it was asked to open. Returns nil for URLs
    /// zContainer doesn't handle.
    init?(url: URL) {
        // Any other file zContainer is asked to open is taken for an IPA.
        if url.isFileURL, Self.certificateFileExtensions.contains(url.pathExtension.lowercased()) {
            self = .certificateFile(url)
            return
        }
        if let link = AppLink(url: url) {
            self = .app(link)
            return
        }
        switch url.host?.lowercased() {
        case "livecontainer-launch", "install", "open-web-page", "open-url":
            self = .home
        case "certificate":
            guard let link = CertificateLink(url: url) else {
                return nil
            }
            self = .certificate(link)
        case ZeusGroupLayout.linkHost:
            // A link that names no request still brings up zContainer.
            let ids = Self.requestIDs(in: url)
            self = ids.isEmpty ? .home : .zeusRequests(ids)
        default:
            return nil
        }
    }

    /// The extensions of the PKCS #12 files a certificate comes in.
    private static let certificateFileExtensions: Set<String> = ["p12", "pfx"]

    /// The requests a `zeus-request` link names: its `id` items that hold a
    /// UUID, each once, in the order given, up to the 50 a link may name.
    /// Other items, and ids that aren't UUIDs, are left out.
    private static func requestIDs(in url: URL) -> [UUID] {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var ids: [UUID] = []
        for item in queryItems where item.name == ZeusGroupLayout.linkIDItem {
            guard let value = item.value, let id = UUID(uuidString: value), !ids.contains(id) else {
                continue
            }
            ids.append(id)
            if ids.count == ZeusGroupLayout.maxIDsPerLink {
                break
            }
        }
        return ids
    }
}
