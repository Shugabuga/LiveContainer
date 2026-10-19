//
//  HomeScreenSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Home Screen: how the icons on zContainer's Home Screen look.
/// Settings shows it on iOS 18 and later, which draw dark icons.
struct HomeScreenSettingsView: View {
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false

    var body: some View {
        List {
            Section {
                Toggle("zc.settings.homeScreen.darkIcons".loc, isOn: $darkModeIcon)
            } footer: {
                Text("zc.settings.homeScreen.darkIconsFooter".loc)
            }
        }
        .navigationTitle("zc.settings.homeScreen".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
