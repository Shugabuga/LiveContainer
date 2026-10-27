//
//  ZeusSetupCheck.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One part of zContainer's setup that Check Setup looks at: what Zeus has to
/// give zContainer when it signs it for the apps inside to work.
enum ZeusSetupCheck: CaseIterable, Hashable {
    /// The app group, which shared apps, the share sheet, the Launch App
    /// shortcut and updates from Zeus need.
    case sharedStorage
    /// The keychain groups, one per container, which keep each container's
    /// sign-ins apart.
    case separateLogins
    /// Signing a test library with the certificate and checking that iOS
    /// accepts it, as it has to for the apps inside to open without JIT.
    case signing

    /// The row's name.
    var title: String {
        switch self {
        case .sharedStorage:
            "zc.settings.setup.sharedStorage".loc
        case .separateLogins:
            "zc.settings.setup.separateLogins".loc
        case .signing:
            "zc.settings.setup.signing".loc
        }
    }

    /// What the part does, under the row's name.
    var detail: String {
        switch self {
        case .sharedStorage:
            "zc.settings.setup.sharedStorageDetail".loc
        case .separateLogins:
            "zc.settings.setup.separateLoginsDetail".loc
        case .signing:
            "zc.settings.setup.signingDetail".loc
        }
    }

    /// The symbol on the row's icon.
    var systemImage: String {
        switch self {
        case .sharedStorage:
            "folder.fill"
        case .separateLogins:
            "key.fill"
        case .signing:
            "checkmark.seal.fill"
        }
    }

    /// The color of the row's icon.
    var color: Color {
        switch self {
        case .sharedStorage:
            .blue
        case .separateLogins:
            .gray
        case .signing:
            .indigo
        }
    }

    /// What is lost while it's missing, under the row's name, for the parts
    /// zContainer works without.
    var missingDetail: String {
        switch self {
        case .sharedStorage:
            "zc.settings.setup.sharedStorageMissing".loc
        case .separateLogins:
            "zc.settings.setup.separateLoginsMissing".loc
        case .signing:
            detail
        }
    }

    /// Whether zContainer works without it. Without the app group, apps run
    /// from zContainer's own storage only, with no shared apps, share sheet
    /// or updates from Zeus; without separate logins, the apps inside share
    /// their sign-ins with one another. Nothing else breaks.
    var isOptional: Bool {
        self != .signing
    }
}
