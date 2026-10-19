//
//  HomeButtonBarPlacement.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Pins the Home button bar to the bottom of a screen and makes room for it,
/// so the screen's last rows can scroll out from under the button. On iOS 26
/// and later it is a safe area bar, which also fades the content scrolling
/// beneath it as toolbars do.
struct HomeButtonBarPlacement: ViewModifier {
    /// What pressing the button does.
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .bottom) {
                HomeButtonBar(action: action)
            }
        } else {
            content.safeAreaInset(edge: .bottom) {
                HomeButtonBar(action: action)
            }
        }
    }
}

extension View {
    /// Shows the Home button centered along the bottom of this screen. Apply
    /// it outside the screen's navigation stack, so every page shows it.
    func homeButtonBar(action: @escaping () -> Void) -> some View {
        modifier(HomeButtonBarPlacement(action: action))
    }
}
