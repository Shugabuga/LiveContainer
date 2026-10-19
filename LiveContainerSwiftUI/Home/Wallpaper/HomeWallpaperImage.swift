//
//  HomeWallpaperImage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What the Home Screen shows behind everything: the chosen photo filling
/// the screen, or black. While Dark Mode is on it's dimmed, unless that's
/// turned off. While search is open, the blurred copy fades in over it.
struct HomeWallpaperImage: View {
    @Environment(WallpaperStore.self) private var wallpaper
    @Environment(SystemAppearance.self) private var system
    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        let isDimmed = wallpaper.dimsInDarkMode && system.isDark

        Color.black
            .overlay {
                if let image = wallpaper.image {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()

                        if let blurred = wallpaper.blurredImage {
                            Image(uiImage: blurred)
                                .resizable()
                                .scaledToFill()
                                .opacity(model.isSearching ? 1 : 0)
                        }

                        Color.black
                            .opacity(isDimmed ? HomeDesign.wallpaperDimming : 0)
                    }
                    .transition(.opacity)
                }
            }
            .clipped()
            .animation(HomeDesign.modeChange, value: wallpaper.image)
            .animation(HomeDesign.modeChange, value: model.isSearching)
            .animation(HomeDesign.modeChange, value: isDimmed)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
