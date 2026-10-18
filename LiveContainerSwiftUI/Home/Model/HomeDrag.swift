//
//  HomeDrag.swift
//  LiveContainerSwiftUI
//

import Foundation

/// An icon being moved in edit mode: where it came from, where it would land
/// if dropped now, and the layout the other icons show to make room for it.
struct HomeDrag: Equatable {
    /// The icon being moved.
    let item: HomeItem
    /// Where the icon was when it was picked up.
    let origin: HomeSlot
    /// The distance from the finger to the icon's center, so the icon doesn't
    /// jump under the finger when it is picked up.
    let grabOffset: CGSize
    /// Where the icon goes if it is dropped now.
    var target: HomeSlot
    /// The layout with the icon at `target`.
    var preview: HomeLayout
}
