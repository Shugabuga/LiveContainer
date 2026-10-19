//
//  HomeIconStyle.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Which versions of apps' icons zContainer shows, chosen in Settings > Home
/// Screen: the dark ones while Dark Mode is on, as iOS does by default, or
/// always the light or the dark ones.
enum HomeIconStyle: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    /// The defaults key the choice is saved under, in the app group's defaults.
    static let storageKey = "ZCHomeIconStyle"

    var id: Self {
        self
    }

    /// The choice's name in Settings.
    var title: String {
        switch self {
        case .automatic:
            "zc.settings.homeScreen.iconStyle.automatic".loc
        case .light:
            "zc.settings.homeScreen.iconStyle.light".loc
        case .dark:
            "zc.settings.homeScreen.iconStyle.dark".loc
        }
    }

    /// Whether icons show in their dark versions, given whether Dark Mode is on.
    func prefersDarkIcons(systemIsDark: Bool) -> Bool {
        switch self {
        case .automatic:
            systemIsDark
        case .light:
            false
        case .dark:
            true
        }
    }
}
