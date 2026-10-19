//
//  WallpaperError.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Why a photo couldn't become the wallpaper.
enum WallpaperError: LocalizedError {
    /// The photo isn't a picture iOS can read.
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "zc.wallpaper.unreadable".loc
        }
    }
}
