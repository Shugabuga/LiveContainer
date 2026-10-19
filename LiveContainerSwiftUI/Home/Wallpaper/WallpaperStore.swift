//
//  WallpaperStore.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The photo the Home Screen shows behind its icons in place of black, a
/// blurred copy of it for behind search, and whether Dark Mode dims it. It's
/// chosen in Settings > Wallpaper or from edit mode's add button, kept as a
/// file the size of the largest screens, and loaded off the main thread at
/// launch.
@MainActor
@Observable
final class WallpaperStore {
    /// The wallpaper, ready to draw, or nil for the black one.
    private(set) var image: UIImage?

    /// The wallpaper blurred, shown behind search. Blurring it once here
    /// spares search a live blur of a full screen photo.
    private(set) var blurredImage: UIImage?

    /// Whether a new wallpaper is being made from a photo.
    private(set) var isPreparing = false

    /// Whether the wallpaper is dimmed a little while Dark Mode is on, so the
    /// white names under the icons read over a bright photo, as on iOS.
    var dimsInDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(dimsInDarkMode, forKey: Self.dimmedKey)
        }
    }

    /// The defaults key `dimsInDarkMode` is saved under.
    private static let dimmedKey = "ZCWallpaperDimmed"

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
        let (image, blurred) = try await Task.detached(priority: .userInitiated) {
            let image = try WallpaperFile.save(data)
            return (image, WallpaperFile.blurred(image))
        }.value
        self.image = image
        blurredImage = blurred
    }

    /// Goes back to the black wallpaper.
    func remove() {
        WallpaperFile.remove()
        image = nil
        blurredImage = nil
    }

    private func load() async {
        let saved = await Task.detached(priority: .userInitiated) {
            WallpaperFile.load().map { image in
                (image, WallpaperFile.blurred(image))
            }
        }.value
        // A wallpaper chosen meanwhile is newer than the saved one.
        guard image == nil, let saved else {
            return
        }
        image = saved.0
        blurredImage = saved.1
    }
}
