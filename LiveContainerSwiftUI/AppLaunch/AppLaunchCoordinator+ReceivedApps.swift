//
//  AppLaunchCoordinator+ReceivedApps.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Installing the apps PendingInstallQueue holds: install links that arrived
/// while onboarding showed, downloaded at once, and IPAs added in its Add
/// Apps step. They go through the same steps as any other install, one at a
/// time, and report which app they added so the step can show it.
extension AppLaunchCoordinator {
    /// Installs an IPA that's already on this iPhone and returns the app it
    /// added, or nil when it added none: the person kept the app already
    /// installed, or the install stopped and `errorMessage` says why.
    /// - Parameters:
    ///   - file: The IPA.
    ///   - isOwnCopy: Whether zContainer downloaded or copied the IPA itself,
    ///     so it can read it as it is. A file opened with zContainer or
    ///     shared to it goes through `installLocalIpa(_:)`, which reaches
    ///     files that need a bookmark or security-scoped access.
    /// - Throws: Why an IPA of zContainer's own couldn't be installed.
    func installReceivedIPA(at file: URL, isOwnCopy: Bool) async throws -> LCAppModel? {
        isInstalling = true
        defer { isInstalling = false }

        let before = Set(allApps.map(ObjectIdentifier.init))
        if isOwnCopy {
            try await installIpaFile(file)
        } else {
            await installLocalIpa(file)
        }
        // A replaced app is a new model in the old one's place, so it counts
        // as added too.
        return allApps.first { !before.contains(ObjectIdentifier($0)) }
    }

    /// Every installed app, hidden or not.
    private var allApps: [LCAppModel] {
        sharedModel.apps + sharedModel.hiddenApps
    }
}
