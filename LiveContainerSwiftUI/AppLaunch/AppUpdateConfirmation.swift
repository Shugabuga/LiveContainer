//
//  AppUpdateConfirmation.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The question asked before an installed app is replaced by another copy of
/// it, such as "Update Delta 1.2 to 1.3?". An update from Zeus asks it in
/// place of the three-way replace question, worded as an update, a downgrade
/// or a reinstall. Choosing Replace in the three-way question asks it too,
/// when the new copy is older.
struct AppUpdateConfirmation: Equatable {
    /// Whether the new copy is newer, older or the same version.
    let kind: AppUpdateConfirmationKind
    /// The installed app's name.
    let appName: String
    /// The installed version as the question names it, like "1.2", or
    /// "1.2 (5)" when only the builds tell the two copies apart.
    let installedVersion: String
    /// The new copy's version, named the same way.
    let incomingVersion: String

    /// Works out the question from the two copies' versions and builds
    /// (CFBundleVersion), a build being nil when the app has none.
    init(appName: String, installedVersion: String, installedBuild: String?, incomingVersion: String, incomingBuild: String?) {
        self.appName = appName
        kind = Self.kind(of: incomingVersion, build: incomingBuild, against: installedVersion, build: installedBuild)

        // The builds only show when the versions are the same and the builds
        // aren't, as Zeus names its own updates, so a new build of the same
        // version doesn't read as the version installed already.
        let sameVersion = AppVersionOrder.compare(version: incomingVersion, build: nil, with: installedVersion, build: nil) == .orderedSame
        if sameVersion, let installedBuild, let incomingBuild,
           AppVersionOrder.compare(version: incomingBuild, build: nil, with: installedBuild, build: nil) != .orderedSame {
            self.installedVersion = "\(installedVersion) (\(installedBuild))"
            self.incomingVersion = "\(incomingVersion) (\(incomingBuild))"
        } else {
            self.installedVersion = installedVersion
            self.incomingVersion = incomingVersion
        }
    }

    /// The question, like "Update Delta 1.2 to 1.3?".
    var title: String {
        switch kind {
        case .update:
            "zc.update.title %@ %@ %@".localizeWithFormat(appName, installedVersion, incomingVersion)
        case .downgrade:
            "zc.update.downgradeTitle %@ %@ %@".localizeWithFormat(appName, installedVersion, incomingVersion)
        case .reinstall:
            "zc.update.reinstallTitle %@ %@".localizeWithFormat(appName, incomingVersion)
        }
    }

    /// What the replacement keeps, and for a downgrade what it may cost.
    var message: String {
        switch kind {
        case .update, .reinstall:
            "zc.update.message %@".localizeWithFormat(appName)
        case .downgrade:
            "zc.update.downgradeMessage %@ %@".localizeWithFormat(incomingVersion, appName)
        }
    }

    /// The button that goes ahead: Update, Replace or Reinstall.
    var confirmTitle: String {
        switch kind {
        case .update:
            "zc.update.confirm".loc
        case .downgrade:
            "zc.update.downgradeConfirm".loc
        case .reinstall:
            "zc.update.reinstallConfirm".loc
        }
    }

    /// Whether going ahead can cost the app its data, as a downgrade can, so
    /// the button shows in red.
    var isDestructive: Bool {
        kind == .downgrade
    }

    /// Whether the new copy is an update, a downgrade or a reinstall.
    private static func kind(of incomingVersion: String, build incomingBuild: String?,
                             against installedVersion: String, build installedBuild: String?) -> AppUpdateConfirmationKind {
        switch AppVersionOrder.compare(version: incomingVersion, build: incomingBuild, with: installedVersion, build: installedBuild) {
        case .orderedDescending:
            .update
        case .orderedAscending:
            .downgrade
        case .orderedSame:
            .reinstall
        }
    }
}
