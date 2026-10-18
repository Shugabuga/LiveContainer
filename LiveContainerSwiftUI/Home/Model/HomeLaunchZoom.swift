//
//  HomeLaunchZoom.swift
//  LiveContainerSwiftUI
//

import Foundation

/// An app zooming open from its icon, just before zContainer turns into it.
struct HomeLaunchZoom: Identifiable, Equatable {
    /// The icon the app opens from.
    let item: HomeItem
    /// The icon's frame on screen, where the zoom starts.
    let iconFrame: CGRect
    /// Tells this zoom from an earlier one of the same app.
    let id = UUID()
}
