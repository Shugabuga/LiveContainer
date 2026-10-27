//
//  ZeusAppsManifest.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The apps zContainer holds, written to zContainer/Apps.json in the shared
/// app group, so Zeus can show which of its apps are inside zContainer and
/// offer their updates. Hidden and locked apps are left out of `apps`,
/// counted, and named only by bundle ID.
struct ZeusAppsManifest: Encodable, Sendable {
    let format = ZeusGroupLayout.format
    let writtenAt: Date
    let host: ZeusManifestHost
    /// How many apps were left out of `apps`: hidden and locked ones, and
    /// any Zeus couldn't use or that didn't fit within the limits.
    var withheldCount: Int
    /// The bundle IDs of the apps left out of `apps`, each once, in order and
    /// at most ZeusGroupLayout.maxManifestApps of them, so Zeus can tell an
    /// app it sent that is still here from one that was deleted. Nothing else
    /// about them is written, and an app without a valid bundle ID is only
    /// counted.
    var withheldBundleIdentifiers: [String]
    var apps: [ZeusManifestApp]
}
