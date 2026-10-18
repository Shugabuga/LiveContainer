//
//  LCAboutLinks.swift
//  LiveContainerSwiftUI
//
//  Where the About page points: zContainer's own source and the project it is
//  built on.
//

import Foundation

enum LCAboutLinks {
    /// zContainer's complete source, build scripts included, which the AGPL asks
    /// every copy of the app to point to. A placeholder for now: replace it with
    /// the public repository (tagged for each release) before shipping.
    static let source = URL(string: "https://github.com/getzeusapp/LiveContainer")!

    static let liveContainer = URL(string: "https://github.com/LiveContainer/LiveContainer")!
    static let liveContainerContributors = URL(string: "https://github.com/LiveContainer/LiveContainer/graphs/contributors")!
    static let khanhduytran0 = URL(string: "https://github.com/khanhduytran0")!
    static let hugeBlack = URL(string: "https://github.com/hugeBlack")!
    static let license = URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!

    /// A link as people read it: host and path, without the scheme.
    static func display(_ url: URL) -> String {
        (url.host ?? "") + url.path
    }
}
