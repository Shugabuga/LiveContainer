//
//  WallpaperFile.swift
//  LiveContainerSwiftUI
//

import CoreImage
import ImageIO
import UIKit

/// The wallpaper's files: the halo zContainer comes with, in its bundle, and
/// in Application Support a JPEG made from the chosen photo, turned upright and made no bigger than the largest screens need,
/// so it loads quickly and doesn't hold a 48 megapixel photo in memory.
enum WallpaperFile {
    /// The longest side, in pixels, a wallpaper is made at: a little more
    /// than the largest iPhone and iPad screens.
    private static let maximumPixelSize = 3000

    /// The JPEG quality the wallpaper is saved at.
    private static let quality = 0.9

    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Wallpaper.jpg")
    }

    /// The saved wallpaper, decoded for drawing, or nil when there's none.
    static func load() -> UIImage? {
        UIImage(contentsOfFile: url.path(percentEncoded: false))?.preparingForDisplay()
    }

    /// The halo zContainer comes with, decoded for drawing: a square one for
    /// iPads, which fills their screens in both orientations, and a tall one
    /// for iPhones. `Scripts/zc/art/wallpaper` renders both.
    static func loadDefault(isPad: Bool) -> UIImage? {
        UIImage(named: isPad ? "DefaultWallpaperPad" : "DefaultWallpaperPhone")?.preparingForDisplay()
    }

    /// Makes a wallpaper from a photo's data, saves it in place of the last
    /// one, and returns it decoded for drawing.
    static func save(_ data: Data) throws -> UIImage {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let picture = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else {
            throw WallpaperError.unreadable
        }
        let image = UIImage(cgImage: picture)
        guard let jpeg = image.jpegData(compressionQuality: quality) else {
            throw WallpaperError.unreadable
        }
        try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try jpeg.write(to: url, options: .atomic)
        return image.preparingForDisplay() ?? image
    }

    /// The wallpaper blurred as search blurs the Home Screen, made at a
    /// quarter of its size, which the blur hides, or nil if it can't be made.
    static func blurred(_ image: UIImage) -> UIImage? {
        guard let picture = image.cgImage else {
            return nil
        }
        let small = CIImage(cgImage: picture).transformed(by: CGAffineTransform(scaleX: blurScale, y: blurScale))
        let blurred = small.clampedToExtent().applyingGaussianBlur(sigma: blurRadius).cropped(to: small.extent)
        guard let output = CIContext().createCGImage(blurred, from: blurred.extent) else {
            return nil
        }
        return UIImage(cgImage: output).preparingForDisplay()
    }

    /// How much smaller the blurred copy is made.
    private static let blurScale = 0.25

    /// The blur's radius on the smaller copy, in its pixels: about the 24
    /// points search blurs the icons by, on a 3x screen.
    private static let blurRadius = 18.0

    /// Deletes the saved wallpaper.
    static func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
