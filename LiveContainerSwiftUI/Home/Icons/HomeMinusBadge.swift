//
//  HomeMinusBadge.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The minus badge on an icon's top left corner in edit mode, which asks
/// whether to remove the app. Its touch area is larger than the badge.
struct HomeMinusBadge: View {
    /// Asks whether to remove the app.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("zc.home.removeApp".loc, systemImage: "minus")
                .labelStyle(.iconOnly)
                .font(.system(size: HomeDesign.minusBadgeSize * 0.5, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: HomeDesign.minusBadgeSize, height: HomeDesign.minusBadgeSize)
                .background(Color(white: 0.85), in: .circle)
                .frame(width: HomeDesign.minimumTouchSize, height: HomeDesign.minimumTouchSize)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}
