//
//  AppLink.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A link that installs, launches or opens something in one of the apps inside
/// zContainer. HomeRouter reads these from the URLs zContainer is opened with,
/// and AppLaunchCoordinator carries them out.
enum AppLink: Equatable {
    /// Installs the IPA at this address, a web address or a file URL. Install
    /// links look like `zcontainer://install?url=<percent-encoded URL>`, the
    /// form Zeus uses (also for `http://127.0.0.1` addresses), and opening an
    /// .ipa file with zContainer makes one too.
    case install(String)

    /// Launches the app installed in the folder `bundleName`, from
    /// `zcontainer://livecontainer-launch?bundle-name=<folder>`. The link may
    /// also name the container to use (`container-folder-name`), a URL for the
    /// app to open (`open-url`, Base64) and whether to wait for JIT (`jit`).
    case launch(bundleName: String, containerFolderName: String?, url: String?, forceJIT: Bool?)

    /// Opens a URL in the app that handles it, or a web page in the built-in
    /// browser, from `open-url` and `open-web-page` links. Their first query
    /// item holds the URL in Base64.
    case openURL(String)

    /// Reads the link from a URL zContainer was opened with. Returns nil for
    /// links that aren't app links, and for app links that ask for nothing, such
    /// as `livecontainer-launch?bundle-name=ui`, which only brings up
    /// zContainer.
    init?(url: URL) {
        if url.isFileURL {
            self = .install(url.absoluteString)
            return
        }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch url.host?.lowercased() {
        case "open-web-page", "open-url":
            guard let encoded = queryItems.first?.value, !encoded.isEmpty,
                  let target = Self.decodeBase64(encoded) else {
                return nil
            }
            self = .openURL(target)
        case "livecontainer-launch":
            var bundleName: String?
            var containerFolderName: String?
            var target: String?
            var forceJIT: Bool?
            for item in queryItems {
                switch item.name {
                case "bundle-name":
                    bundleName = item.value ?? bundleName
                case "container-folder-name":
                    containerFolderName = item.value ?? containerFolderName
                case "jit":
                    forceJIT = switch item.value {
                    case "true": true
                    case "false": false
                    default: forceJIT
                    }
                case "open-url":
                    target = item.value.flatMap(Self.decodeBase64) ?? target
                default:
                    break
                }
            }
            guard let bundleName, !bundleName.isEmpty, bundleName != "ui" else {
                return nil
            }
            self = .launch(bundleName: bundleName, containerFolderName: containerFolderName, url: target, forceJIT: forceJIT)
        case "install":
            guard let address = queryItems.last(where: { $0.name == "url" && $0.value != nil })?.value else {
                return nil
            }
            self = .install(address)
        default:
            return nil
        }
    }

    /// The UTF-8 text a Base64 query value holds, or nil when it holds none.
    private static func decodeBase64(_ value: String) -> String? {
        guard let data = Data(base64Encoded: value) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
