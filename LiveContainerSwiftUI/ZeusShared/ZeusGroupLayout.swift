//
//  ZeusGroupLayout.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What zContainer and Zeus agree on for the app group they share
/// (group.app.reiko.zeus followed by the team): the names of the folders and
/// files in it, their limits and how long a request stays valid. Zeus keeps
/// the same values in SharedGroupLayout.swift, so a change here needs the
/// same change there.
///
/// Zeus writes only in Zeus/Requests: a folder for each request, named by its
/// id, with request.json and the app or certificate it sends. zContainer
/// writes only in zContainer: Apps.json, the apps it holds, and a result for
/// each request in Results. zContainer deletes ZeusCertificate.plist as soon
/// as it has read it; apart from that, neither deletes what the other wrote.
enum ZeusGroupLayout {
    /// The version of this layout, written into every file as "format".
    static let format = 1

    // MARK: Zeus's folders and files

    static let zeusFolderName = "Zeus"
    static let requestsFolderName = "Requests"
    /// Zeus fills a request's folder under this prefix, then renames it to
    /// the request's id, so a folder named by an id is always complete.
    static let stagingPrefix = ".staging-"
    static let requestFileName = "request.json"
    static let appPayloadFileName = "app.ipa"
    static let certificatePayloadFileName = "ZeusCertificate.plist"

    // MARK: zContainer's folders and files

    static let zContainerFolderName = "zContainer"
    static let manifestFileName = "Apps.json"
    static let resultsFolderName = "Results"
    /// A result is named by its request's id with this extension.
    static let resultFileExtension = "json"

    // MARK: Links

    /// Zeus opens zContainer with SCHEME://zeus-request?id=UUID&id=UUID.
    static let linkHost = "zeus-request"
    static let linkIDItem = "id"
    static let maxIDsPerLink = 50

    // MARK: Sizes, in bytes

    static let maxRequestSize = 64 * 1024
    static let maxCertificateSize = 64 * 1024
    static let maxManifestSize = 1024 * 1024
    static let maxResultSize = 64 * 1024
    static let maxAppPayloadSize: Int64 = 8 * 1024 * 1024 * 1024

    // MARK: Lengths, in characters

    /// The apps Apps.json lists at most.
    static let maxManifestApps = 2000
    static let maxStringLength = 512
    static let maxMessageLength = 300
    static let maxVersionLength = 64
    static let maxBundleIdentifierLength = 255
    static let maxFolderLength = 255

    // MARK: Time windows, in seconds

    /// An app request named by a link from Zeus.
    static let appRequestLinkLifetime: TimeInterval = 86400
    /// An app request found by a rescan, after a guest app caught the link
    /// meant for zContainer, or zContainer couldn't be opened while Zeus was
    /// in the background. It's as long as a link's, the day Zeus waits for an
    /// answer, so a request Zeus still shows as waiting is never left behind.
    /// zContainer still asks before it installs anything.
    static let appRequestRescanLifetime: TimeInterval = 86400
    /// A certificate request, either way.
    static let certificateLifetime: TimeInterval = 900
    /// How far ahead of this iPhone's clock a request may be dated.
    static let futureSkew: TimeInterval = 300
    /// How long zContainer keeps a result before sweeping it.
    static let resultLifetime: TimeInterval = 604800
    /// How long Zeus keeps a staging folder before sweeping it. zContainer
    /// never reads those folders.
    static let stagingLifetime: TimeInterval = 3600

    /// How many request ids zContainer remembers taking.
    static let takenLimit = 200
}
