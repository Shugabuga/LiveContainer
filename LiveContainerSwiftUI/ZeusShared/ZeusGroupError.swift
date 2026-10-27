//
//  ZeusGroupError.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Why zContainer can't use a request Zeus left in the shared app group.
enum ZeusGroupError: Error {
    /// zContainer doesn't share an app group with Zeus.
    case unreachable
    /// No request with that id is in the group, or something other than a
    /// folder stands in its place.
    case missing
    /// The request is incomplete, too large or not what Zeus writes.
    case unreadable
    /// The request is older than it may be, or dated too far ahead.
    case expired
    /// The copy of the app doesn't have the size or SHA-256 Zeus gave.
    case damaged
}
