//
//  HomePresentedScreen.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A screen that opens over the Home Screen the way an app opens: zooming out
/// of the icon it belongs to.
enum HomePresentedScreen: Identifiable {
    /// zContainer's Settings.
    case settings
    /// One app's settings.
    case appSettings(LCAppModel)

    var id: String {
        sourceItem?.id ?? "appSettings"
    }

    /// The icon the screen zooms out of: Settings, or the app's icon.
    var sourceItem: HomeItem? {
        switch self {
        case .settings:
            .settings
        case .appSettings(let app):
            app.homeKey.map(HomeItem.app)
        }
    }
}
