//
//  HomeSlot.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A place for an icon: a position on one of the pages, or in the dock.
/// Positions count from 0, left to right and then top to bottom, the way iOS
/// fills a page.
enum HomeSlot: Hashable, Sendable {
    /// The position `index` on the page `page`.
    case page(Int, index: Int)

    /// The position `index` in the dock.
    case dock(Int)

    /// The page this slot is on, or nil for the dock.
    var page: Int? {
        if case .page(let page, _) = self {
            page
        } else {
            nil
        }
    }

    /// Whether this slot is in the dock.
    var isInDock: Bool {
        if case .dock = self {
            true
        } else {
            false
        }
    }
}
