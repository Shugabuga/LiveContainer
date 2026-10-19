//
//  SettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's Settings, opened from the Settings icon on the Home Screen
/// and laid out like the Settings app: a large "Settings" title over a
/// grouped list, with Zeus at the top where the Apple Account sits. On iPad
/// the list is a sidebar with the page picked in it beside it, as in the
/// iPad's Settings app (SettingsSplitView).
///
/// Every page is pushed with NavigationLink's destination form, because the
/// LiveContainer pages it reuses (About, Storage, the app settings, Tweaks
/// and the rest) push theirs that way, and the two forms shouldn't be mixed
/// in one navigation stack.
struct SettingsView: View {
    /// The certificate and setup state the pages share.
    @State private var connection = ZeusConnection()

    var body: some View {
        Group {
            // SharedModel.isPhone never changes while zContainer runs, so
            // Settings never switches between the two layouts.
            if SharedModel.isPhone {
                NavigationStack {
                    SettingsRootList()
                        .navigationTitle("lc.tabView.settings".loc)
                }
            } else {
                SettingsSplitView()
            }
        }
        .environment(connection)
    }
}
