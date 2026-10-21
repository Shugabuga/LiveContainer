//
//  AppLaunchCoordinator+ReceivedApps.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Installing the apps PendingInstallQueue holds: install links that arrived
/// while onboarding showed, downloaded at once, IPAs added in its Add Apps
/// step, and the apps Zeus sends through the app group the two apps share.
/// They go through the same steps as any other install, one at a time, and
/// report how they ended so the queue can show the app and tell Zeus.
extension AppLaunchCoordinator {
    /// Installs an IPA that's already on this iPhone, once no other install
    /// runs, and says how it ended.
    /// - Parameters:
    ///   - file: The IPA.
    ///   - isOwnCopy: Whether zContainer downloaded or copied the IPA itself,
    ///     so it can read it as it is. A file opened with zContainer or
    ///     shared to it goes through `installLocalIpa(_:policy:)`, which
    ///     reaches files that need a bookmark or security-scoped access.
    ///   - policy: What to do when the app is installed already. An app Zeus
    ///     sent is one of zContainer's own copies.
    /// - Returns: The app added or replaced, or `.cancelled` when it added
    ///   none: the person kept the app already installed, or a file that
    ///   isn't zContainer's own couldn't be installed and `errorMessage` says
    ///   why.
    /// - Throws: Why an IPA of zContainer's own couldn't be installed.
    func installReceivedIPA(at file: URL, isOwnCopy: Bool, policy: AppInstallPolicy = .ask) async throws -> AppInstallOutcome {
        await waitForInstallTurn()
        isInstalling = true
        defer { isInstalling = false }

        if isOwnCopy {
            return try await installIpaFile(file, policy: policy)
        }
        return await installLocalIpa(file, policy: policy)
    }
}
