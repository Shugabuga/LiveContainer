//
//  HomePresentedScreenView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The screen open over the Home Screen: zContainer's Settings, or an app's
/// settings.
struct HomePresentedScreenView: View {
    /// Which screen to show.
    let screen: HomePresentedScreen

    var body: some View {
        switch screen {
        case .settings:
            LCSettingsView()
        case .appSettings(let app):
            HomeAppSettingsScreen(app: app)
        }
    }
}
