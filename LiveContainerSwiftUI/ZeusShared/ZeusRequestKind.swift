//
//  ZeusRequestKind.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What a request from Zeus sends.
enum ZeusRequestKind: String, Decodable, Sendable {
    /// An app to install, or to replace the copy zContainer holds with.
    case app
    /// Zeus's certificate, for zContainer to sign apps with.
    case certificate

    /// The file next to request.json that carries what the request sends.
    var payloadFileName: String {
        switch self {
        case .app:
            ZeusGroupLayout.appPayloadFileName
        case .certificate:
            ZeusGroupLayout.certificatePayloadFileName
        }
    }

    /// How long a request stays valid after Zeus wrote it: an app request a
    /// day, whether a link from Zeus names it or a rescan finds it, as long as
    /// Zeus waits for its answer, and a certificate request 15 minutes.
    func lifetime(fromLink: Bool) -> TimeInterval {
        switch self {
        case .app:
            fromLink ? ZeusGroupLayout.appRequestLinkLifetime : ZeusGroupLayout.appRequestRescanLifetime
        case .certificate:
            ZeusGroupLayout.certificateLifetime
        }
    }
}
