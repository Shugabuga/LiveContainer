//
//  HomeScreenSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Home Screen: how the icons on zContainer's Home Screen look.
/// Settings shows it on iOS 18 and later, which draw dark icons. By default
/// the icons follow Dark Mode, as iOS's own do.
struct HomeScreenSettingsView: View {
    @AppStorage(HomeIconStyle.storageKey, store: LCUtils.appGroupUserDefault) private var iconStyle = HomeIconStyle.automatic

    var body: some View {
        List {
            Section {
                Picker("zc.settings.homeScreen.iconStyle".loc, selection: $iconStyle) {
                    ForEach(HomeIconStyle.allCases) { style in
                        Text(style.title)
                            .tag(style)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("zc.settings.homeScreen.iconStyle".loc)
            } footer: {
                Text("zc.settings.homeScreen.iconStyleFooter".loc)
            }
        }
        .navigationTitle("zc.settings.homeScreen".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
