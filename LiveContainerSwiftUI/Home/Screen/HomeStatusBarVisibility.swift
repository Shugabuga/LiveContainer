//
//  HomeStatusBarVisibility.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Hides the status bar while edit mode's buttons take its place, using the
/// status bar toolbar placement on iOS 27 and later.
struct HomeStatusBarVisibility: ViewModifier {
    /// Whether the status bar is hidden.
    let isHidden: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content.toolbarVisibility(isHidden ? .hidden : .automatic, for: .statusBar)
        } else {
            content.statusBarHidden(isHidden)
        }
    }
}

extension View {
    /// Hides the status bar while `isHidden` is true.
    func homeStatusBarHidden(_ isHidden: Bool) -> some View {
        modifier(HomeStatusBarVisibility(isHidden: isHidden))
    }
}
