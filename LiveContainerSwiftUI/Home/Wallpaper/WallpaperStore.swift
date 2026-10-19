//
//  WallpaperStore.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What the Home Screen shows behind its icons: the halo zContainer comes
/// with, or a photo chosen in Settings > Wallpaper or from edit mode's add
/// button. It keeps a blurred copy for behind search, and whether Dark Mode
/// dims a photo. A photo is kept as a file the size of the largest screens;
/// either is loaded off the main thread at launch.
@MainActor
@Observable
final class WallpaperStore {
    /// The wallpaper, ready to draw. Nil only until it has loaded.
    private(set) var image: UIImage?

    /// The wallpaper blurred, shown behind search. Blurring it once here
    /// spares search a live blur of a full screen picture.
    private(set) var blurredImage: UIImage?

    /// Whether the wallpaper is a photo the person chose, rather than the
    /// halo zContainer comes with.
    private(set) var isCustom = false

    /// Whether a new wallpaper is being made from a photo.
    private(set) var isPreparing = false

    /// Whether a photo is dimmed a little while Dark Mode is on, so the white
    /// names under the icons read over its bright parts, as on iOS. The halo
    /// is made dark already, so it's never dimmed.
    var dimsInDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(dimsInDarkMode, forKey: Self.dimmedKey)
        }
    }

    /// The defaults key `dimsInDarkMode` is saved under.
    private static let dimmedKey = "ZCWallpaperDimmed"

    /// Counts the wallpapers set, so one that finishes loading late can't
    /// replace a newer one.
    @ObservationIgnored private var generation = 0

    init() {
        dimsInDarkMode = UserDefaults.standard.object(forKey: Self.dimmedKey) as? Bool ?? true
        Task {
            await load()
        }
    }

    /// Makes a photo's data the wallpaper. Throws when it isn't a picture
    /// iOS can read, leaving the wallpaper as it was.
    func set(_ data: Data) async throws {
        isPreparing = true
        defer {
            isPreparing = false
        }
        generation += 1
        let (image, blurred) = try await Task.detached(priority: .userInitiated) {
            let image = try WallpaperFile.save(data)
            return (image, WallpaperFile.blurred(image))
        }.value
        self.image = image
        blurredImage = blurred
        isCustom = true
    }

    /// Goes back to the halo zContainer comes with.
    func useDefault() {
        WallpaperFile.remove()
        isCustom = false
        Task {
            await load()
        }
    }

    /// Loads the saved photo, or the halo when there's none: the iPad's
    /// square one on an iPad, which fills the screen either way up.
    private func load() async {
        generation += 1
        let loading = generation
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let loaded = await Task.detached(priority: .userInitiated) {
            let photo = WallpaperFile.load()
            return (photo ?? WallpaperFile.loadDefault(isPad: isPad)).map { image in
                (image, WallpaperFile.blurred(image), photo != nil)
            }
        }.value
        // A wallpaper set meanwhile is newer than this one.
        guard loading == generation, let loaded else {
            return
        }
        image = loaded.0
        blurredImage = loaded.1
        isCustom = loaded.2
    }
}
