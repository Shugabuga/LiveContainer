//
//  ZeusRequestResult.swift
//  LiveContainerSwiftUI
//

import Foundation

/// zContainer's answer to a request from Zeus, which ZeusGroup.writeResult
/// writes to zContainer/Results/ID.json in the shared app group for Zeus to
/// read the next time it becomes active. Strings are cut to the contract's
/// limits, and values Zeus would refuse are left out.
struct ZeusRequestResult: Encodable, Sendable {
    let format = ZeusGroupLayout.format
    let id: UUID
    let outcome: ZeusRequestOutcome
    /// Why the request failed. Only a failed result has one.
    let reason: ZeusRequestFailure?
    /// What went wrong, as the person read it in zContainer.
    let message: String?

    // MARK: The app as zContainer now holds it, after added or replaced

    let bundleIdentifier: String?
    let name: String?
    let folder: String?
    let version: String?
    let build: String?

    let finishedAt: Date

    /// A result that names no app: cancelled, failed, accepted or declined.
    init(id: UUID, outcome: ZeusRequestOutcome, failure: ZeusRequestFailure? = nil, message: String? = nil, finishedAt: Date = .now) {
        self.id = id
        self.outcome = outcome
        reason = outcome == .failed ? failure : nil
        self.message = message.map { ZeusGroupRules.clipped($0, to: ZeusGroupLayout.maxMessageLength) }
        bundleIdentifier = nil
        name = nil
        folder = nil
        version = nil
        build = nil
        self.finishedAt = finishedAt
    }

    /// A result naming the app a request added or replaced, so Zeus knows
    /// which copy holds which version. The version and build come from the
    /// app's Info.plist.
    @MainActor
    init(id: UUID, outcome: ZeusRequestOutcome, app: LCAppModel) {
        let appInfo = app.appInfo
        let versions = ZeusGroup.versions(ofAppAt: appInfo.bundlePath())
        self.id = id
        self.outcome = outcome
        reason = nil
        message = nil
        bundleIdentifier = appInfo.bundleIdentifier().flatMap { ZeusGroupRules.isBundleIdentifier($0) ? $0 : nil }
        name = appInfo.displayName().map { ZeusGroupRules.clipped($0, to: ZeusGroupLayout.maxStringLength) }
        folder = appInfo.relativeBundlePath.flatMap { ZeusGroupRules.isFolder($0) ? $0 : nil }
        version = versions.version
        build = versions.build
        finishedAt = .now
    }
}
