//
//  HomePresentedScreenView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The screen open over the Home Screen: zContainer's Settings, or an app's
/// settings. The Home button at the bottom goes back to the Home Screen from
/// any of its pages.
struct HomePresentedScreenView: View {
    /// Which screen to show.
    let screen: HomePresentedScreen

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        Group {
            switch screen {
            case .settings:
                SettingsView()
            case .appSettings(let app):
                HomeAppSettingsScreen(app: app)
            }
        }
        .homeButtonBar(action: model.goHome)
    }
}
