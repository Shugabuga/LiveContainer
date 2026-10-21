//
//  ZeusGroupRules.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The checks a value from the shared app group passes before zContainer
/// uses it. Zeus runs the same ones on what zContainer writes there
/// (SharedGroupValidation in Zeus).
///
/// Names are checked byte by byte rather than by character, since that is
/// how the file system reads them: a slash or a dot followed by an accent is
/// one character to Swift, but still a slash or a dot on disk.
enum ZeusGroupRules {
    /// The bytes a bundle ID may have.
    private static let bundleIdentifierBytes = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-".utf8)
    /// The bytes a SHA-256 in lowercase hexadecimal may have.
    private static let lowercaseHexBytes = Set("0123456789abcdef".utf8)
    private static let dot = UInt8(ascii: ".")
    private static let slash = UInt8(ascii: "/")

    /// Whether a string is a request id the way both sides write it: a UUID
    /// in its usual uppercase form, which also names the request's folder.
    static func isRequestID(_ string: String) -> Bool {
        UUID(uuidString: string)?.uuidString == string
    }

    /// Whether a string can be a bundle ID: 1 to 255 letters, digits, dots,
    /// underscores and hyphens, not starting with a dot.
    static func isBundleIdentifier(_ string: String) -> Bool {
        let bytes = string.utf8
        return (1...ZeusGroupLayout.maxBundleIdentifierLength).contains(bytes.count)
            && bytes.first != dot
            && bytes.allSatisfy(bundleIdentifierBytes.contains)
    }

    /// Whether a string can be the folder of an app in zContainer: one name
    /// of 1 to 255 bytes ending in .app, with no slash, NUL or leading dot,
    /// so it can't lead out of the folder it is looked up in.
    static func isFolder(_ string: String) -> Bool {
        let bytes = string.utf8
        return (1...ZeusGroupLayout.maxFolderLength).contains(bytes.count)
            && bytes.first != dot
            && bytes.suffix(4).elementsEqual(".app".utf8)
            && !bytes.contains(slash)
            && !bytes.contains(0)
    }

    /// Whether a string is a SHA-256 digest the way both sides write it: 64
    /// lowercase hexadecimal digits.
    static func isSHA256(_ string: String) -> Bool {
        let bytes = string.utf8
        return bytes.count == 64 && bytes.allSatisfy(lowercaseHexBytes.contains)
    }

    /// A string cut to at most `limit` characters.
    static func clipped(_ string: String, to limit: Int) -> String {
        string.count > limit ? String(string.prefix(limit)) : string
    }
}
