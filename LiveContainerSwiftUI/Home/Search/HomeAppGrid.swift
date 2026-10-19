//
//  HomeAppGrid.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Apps in rows of four with their names, as search shows them. A tap opens
/// an app and a long press opens its menu, without Edit Home Screen.
struct HomeAppGrid: View {
    /// The apps to show.
    let apps: [LCAppModel]
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics

    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4), spacing: HomeDesign.searchSpacing) {
            ForEach(apps, id: \.self) { app in
                HomeSearchResult(app: app, metrics: metrics, darkModeIcon: darkModeIcon)
            }
        }
    }
}
