//
//  WallpaperPreview.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The wallpaper as the Home Screen shows it, small and in the screen's
/// shape, with a spinner while a new one is being made.
struct WallpaperPreview: View {
    @Environment(WallpaperStore.self) private var wallpaper
    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        let height = Self.height
        let screen = (model.metrics ?? .reference).size
        let width = screen.height > 0 ? height * screen.width / screen.height : height / 2

        HomeWallpaperImage()
            .frame(width: width, height: height)
            .overlay {
                if wallpaper.isPreparing {
                    ProgressView()
                        .tint(.white)
                }
            }
            .clipShape(.rect(cornerRadius: height * Self.cornerFraction))
            .overlay {
                RoundedRectangle(cornerRadius: height * Self.cornerFraction)
                    .strokeBorder(.separator, lineWidth: 1)
            }
            .padding(.vertical, 8)
            .accessibilityElement()
            .accessibilityLabel("zc.settings.wallpaper.preview".loc)
    }

    /// The preview's height. It's a picture, so it keeps its size whatever
    /// the text size.
    private static let height = 300.0

    /// The preview's corner radius as a fraction of its height, about the
    /// screen's own.
    private static let cornerFraction = 0.058
}
