//
//  HomeScreenModel+HomeButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home button, zContainer's stand-in for the iPhone's: what pressing it
/// does, and when the Home Screen shows it. Screens opened over the Home
/// Screen and search show it too, each in its own place.
extension HomeScreenModel {
    /// Does what pressing Home does on iOS, one step at a time. A screen open
    /// over the Home Screen closes, along with search behind it, as opening an
    /// app from search would have closed it. Otherwise search closes, then
    /// edit mode ends, and otherwise the first page comes back.
    func goHome() {
        if presentedScreen != nil {
            presentedScreen = nil
            if isSearching {
                closeSearch()
            }
        } else if isSearching {
            closeSearch()
        } else if isEditing {
            endEditing()
        } else if (page ?? 0) != 0 {
            withAnimation(HomeDesign.reflow) {
                page = 0
            }
        }
    }

    /// What the row above the dock shows. The page dots take it while the
    /// pages move or an icon is dragged. Otherwise the Home button does when
    /// pressing it would do something, in edit mode and away from the first
    /// page, and "Search" does on the first page, so the Home Screen there
    /// looks exactly like the iPhone's.
    var pillContent: HomePillContent {
        if pageCount > 1 && (showsPageDots || drag != nil) {
            .pageDots
        } else if isEditing || (page ?? 0) != 0 {
            .homeButton
        } else {
            .search
        }
    }
}
