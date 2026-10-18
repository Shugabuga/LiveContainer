//
//  HomeWallpaper.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The empty space behind the icons, which reacts as the iOS wallpaper does:
/// a long press starts edit mode, a tap ends it, and pulling down opens
/// search. VoiceOver reaches the same things through the icons' menus, Done
/// and the search pill, so this space stays out of its way.
struct HomeWallpaper: View {
    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        Color.clear
            .contentShape(.rect)
            // A tap anywhere on the wallpaper has no button to belong to.
            .onTapGesture(perform: model.wallpaperTapped)
            .onLongPressGesture(perform: model.beginEditing)
            .simultaneousGesture(pullDown, including: model.isEditing ? .subviews : .all)
            .accessibilityHidden(true)
    }

    private var pullDown: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded(pullEnded)
    }

    /// Opens search after a pull that went mostly straight down.
    private func pullEnded(_ value: DragGesture.Value) {
        let distance = value.translation
        if distance.height > HomeDesign.pullToSearchDistance && abs(distance.width) < distance.height * 0.6 {
            model.openSearch()
        }
    }
}
