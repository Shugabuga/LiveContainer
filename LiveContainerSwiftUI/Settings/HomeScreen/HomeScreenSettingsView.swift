//
//  HomeScreenSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Home Screen: how the icons on zContainer's Home Screen look, on
/// iOS 18 and later, which draw dark icons, where by default they follow Dark
/// Mode, as iOS's own do; and zContainer's own icon on the iPhone's Home
/// Screen, which a second zContainer doesn't offer, so it keeps the icon that
/// tells it apart.
struct HomeScreenSettingsView: View {
    @AppStorage(HomeIconStyle.storageKey, store: LCUtils.appGroupUserDefault) private var iconStyle = HomeIconStyle.automatic

    var body: some View {
        List {
            if #available(iOS 18.0, *) {
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

            if UIApplication.shared.supportsAlternateIcons && DataManager.shared.model.multiLCStatus != 2 {
                Section {
                    AppIconPicker()
                } header: {
                    Text("zc.settings.appIcon".loc)
                } footer: {
                    Text("zc.settings.appIconFooter".loc)
                }
            }
        }
        .navigationTitle("zc.settings.homeScreen".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
