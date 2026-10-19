//
//  HiddenAppsSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Apps > Hidden Apps, opened after Face ID: the hidden apps, each
/// opening its settings, where turning off Hide brings it back to the Home
/// Screen, and Strict Hiding, which keeps links and other apps from opening
/// hidden apps. It replaces LiveContainer's triple tap on the app counter.
struct HiddenAppsSettingsView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @AppStorage("LCStrictHiding", store: LCUtils.appGroupUserDefault) private var strictHiding = false

    var body: some View {
        List {
            Section {
                if sharedModel.hiddenApps.isEmpty {
                    Text("zc.home.noHiddenApps".loc)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(hiddenApps, id: \.self) { app in
                        NavigationLink {
                            SettingsAppPage(app: app)
                        } label: {
                            SettingsAppRow(app: app)
                        }
                    }
                }
            } footer: {
                Text("zc.settings.apps.hiddenFooter".loc)
            }

            Section {
                Toggle("lc.settings.strictHiding".loc, isOn: $strictHiding)
            } footer: {
                Text("zc.settings.apps.strictHidingFooter".loc)
            }
        }
        .navigationTitle("lc.appList.hiddenApps".loc)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The hidden apps by name.
    private var hiddenApps: [LCAppModel] {
        sharedModel.hiddenApps.sorted { first, second in
            first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
        }
    }
}
