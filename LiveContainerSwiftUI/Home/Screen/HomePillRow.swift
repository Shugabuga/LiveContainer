//
//  HomePillRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The row above the dock. On the first page it holds the "Search" pill, as
/// on iOS, and the page dots while the pages move. The dock fills the bottom
/// of the screen, so the Home button takes this row instead whenever pressing
/// it would do something: in edit mode and on the other pages.
struct HomePillRow: View {
    @Environment(HomeScreenModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let content = model.pillContent

        ZStack {
            if content == .homeButton {
                HomeButton(action: model.goHome)
                    .transition(transition)
            } else {
                HomeSearchPill(
                    pageCount: model.pageCount,
                    currentPage: model.page ?? 0,
                    showsPageDots: content == .pageDots,
                    action: model.openSearch
                )
                .transition(transition)
            }
        }
        .animation(HomeDesign.modeChange, value: content)
    }

    /// The button and the pill grow out of each other, or only fade with
    /// Reduce Motion on.
    private var transition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.8))
    }
}
