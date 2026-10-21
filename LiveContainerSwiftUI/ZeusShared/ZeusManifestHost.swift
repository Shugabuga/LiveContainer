//
//  ZeusManifestHost.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The zContainer that wrote Apps.json. Zeus reads the list only when the
/// team and group match its own.
struct ZeusManifestHost: Encodable, Sendable {
    let bundleIdentifier: String
    /// From zContainer's Info.plist, left out when it gives none.
    let version: String?
    let build: String?
    let teamIdentifier: String
    let groupIdentifier: String
}
