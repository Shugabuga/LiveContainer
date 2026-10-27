//
//  ZeusManifestApp.swift
//  LiveContainerSwiftUI
//

import Foundation

/// One app in Apps.json, as Zeus needs it to offer updates and open the app
/// inside zContainer.
struct ZeusManifestApp: Encodable, Sendable {
    let bundleIdentifier: String
    /// The app's folder in zContainer, which a livecontainer-launch link
    /// opens it by and an update request names to replace it.
    let folder: String
    let name: String
    /// From the app's Info.plist, filled in when the list is written.
    var version: String?
    var build: String?
    /// Whether the app keeps its data in the app group, where another
    /// zContainer finds it too.
    let isShared: Bool
    let installedAt: Date?
}
