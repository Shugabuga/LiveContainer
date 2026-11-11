//
//  ZeusRequestFailure.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Why a request from Zeus failed, written as the result's reason.
enum ZeusRequestFailure: String, Encodable, Sendable {
    /// The app to replace is open.
    case running
    /// The app has another bundle ID than the request gave.
    case mismatch
    /// The copy of the app doesn't have the size or SHA-256 Zeus gave.
    case damaged
    /// The request or what it sends couldn't be read, or it expired.
    case unreadable
    /// The certificate belongs to another team than zContainer's.
    case otherTeam
    /// This is a second zContainer, which leaves apps and certificates to
    /// the first one.
    case secondary
}
