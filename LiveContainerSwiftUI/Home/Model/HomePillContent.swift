//
//  HomePillContent.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What the row above the dock shows.
enum HomePillContent: Equatable {
    /// The "Search" pill, on the first page when nothing else is going on.
    case search
    /// The page dots, while the pages move or an icon is being dragged.
    case pageDots
    /// The Home button, when pressing it would do something: in edit mode
    /// and on every page but the first.
    case homeButton
}
