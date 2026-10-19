//
//  PendingInstallSource.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where an app waiting in PendingInstallQueue came from.
enum PendingInstallSource: Equatable {
    /// An install link's web address. Zeus sends `zcontainer://install?url=`
    /// links to an https download, or to a one-time `http://127.0.0.1`
    /// address that only answers for about a minute.
    case link(URL)

    /// An IPA opened with zContainer or shared to it. It may need a bookmark
    /// or security-scoped access to read, which the install takes care of.
    case openedFile(URL)

    /// An IPA picked in Files, which Files copied for zContainer.
    case pickedFile(URL)

    /// Whether the IPA is a copy of zContainer's own, which it deletes once
    /// installed. A downloaded link's copy is, and so is Files' copy.
    var isOwnCopy: Bool {
        switch self {
        case .link, .pickedFile:
            true
        case .openedFile:
            false
        }
    }

    /// What to call the app until it's installed and its own name is known:
    /// the IPA's file name, or for a link, where it comes from when the link
    /// doesn't name the IPA. Zeus's one-time links all end in `app.ipa`, so
    /// they say they're from Zeus instead.
    var name: String {
        switch self {
        case .link(let url):
            if Self.isLocal(url) {
                "zc.onboarding.apps.fromZeus".loc
            } else if Self.isIPA(url) {
                url.deletingPathExtension().lastPathComponent
            } else {
                url.host ?? url.absoluteString
            }
        case .openedFile(let url), .pickedFile(let url):
            url.deletingPathExtension().lastPathComponent
        }
    }

    /// The name to save a link's download under: its own when it names an
    /// IPA, or a stand-in, since the install reads the file whatever it's
    /// called.
    static func downloadName(for url: URL) -> String {
        isIPA(url) ? url.lastPathComponent : "App.ipa"
    }

    private static func isIPA(_ url: URL) -> Bool {
        ["ipa", "tipa"].contains(url.pathExtension.lowercased())
    }

    /// Whether a link points at this iPhone, as Zeus's one-time links do.
    private static func isLocal(_ url: URL) -> Bool {
        ["127.0.0.1", "localhost", "::1"].contains(url.host?.lowercased() ?? "")
    }
}
