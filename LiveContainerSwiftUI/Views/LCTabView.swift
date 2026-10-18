//
//  TabView.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/21.
//

import Foundation
import SwiftUI

/// LiveContainer's tabs, kept as the main window's root until the Home Screen
/// replaces them. HomeRouter runs the launch checks and routes links; the tabs
/// only follow each route to the screen it concerns.
struct LCTabView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(HomeRouter.self) private var router

    var body: some View {
        TabView(selection: $sharedModel.selectedTab) {
            if DataManager.shared.model.multiLCStatus != 2 {
                LCSourcesView()
                    .tabItem {
                        Label("lc.tabView.sources".loc, systemImage: "books.vertical")
                    }
                    .tag(LCTabIdentifier.sources)
            }
            LCAppListView()
                .tabItem {
                    Label("lc.tabView.apps".loc, systemImage: "square.stack.3d.up.fill")
                }
                .tag(LCTabIdentifier.apps)
            if DataManager.shared.model.multiLCStatus != 2 {
                LCTweaksView()
                    .tabItem{
                        Label("lc.tabView.tweaks".loc, systemImage: "wrench.and.screwdriver")
                    }
                    .tag(LCTabIdentifier.tweaks)
            }
            
            LCSettingsView()
                .tabItem {
                    Label("lc.tabView.settings".loc, systemImage: "gearshape.fill")
                }
                .tag(LCTabIdentifier.settings)
        }
        .homeRouting(router, onRoute: showTab)
    }

    /// Brings up the tab that shows what a link started: the app list for app
    /// links, which shows install progress, and Sources for a source link.
    private func showTab(for route: HomeRoute) {
        switch route {
        case .home, .app:
            sharedModel.selectedTab = .apps
        case .source:
            sharedModel.selectedTab = .sources
        case .certificate:
            break
        }
    }
}
