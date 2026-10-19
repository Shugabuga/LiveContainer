//
//  WallpaperSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Wallpaper: the Home Screen's wallpaper, with a way to choose a
/// photo for it, dim it, or go back to the halo zContainer comes with.
struct WallpaperSettingsView: View {
    @Environment(WallpaperStore.self) private var wallpaper
    @State private var isChoosing = false

    var body: some View {
        @Bindable var wallpaper = wallpaper
        let hasPhoto = wallpaper.isCustom

        List {
            Section {
                WallpaperPreview()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            Section {
                Button("zc.settings.wallpaper.choose".loc, action: choose)
                    .disabled(wallpaper.isPreparing)
                if hasPhoto {
                    Toggle("zc.settings.wallpaper.dim".loc, isOn: $wallpaper.dimsInDarkMode)
                }
            } footer: {
                if hasPhoto {
                    Text("zc.settings.wallpaper.dimFooter".loc)
                }
            }

            if hasPhoto {
                Section {
                    Button("zc.settings.wallpaper.useDefault".loc, action: wallpaper.useDefault)
                }
            }
        }
        .navigationTitle("zc.settings.wallpaper".loc)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: hasPhoto)
        .wallpaperPicker(isPresented: $isChoosing)
    }

    private func choose() {
        isChoosing = true
    }
}
