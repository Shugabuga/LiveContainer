//
//  HomeEditControls.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The buttons edit mode shows where the status bar was: add an app at the
/// top left, Done at the top right.
struct HomeEditControls: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        HStack {
            HomeAddAppMenu(size: metrics.editButtonSize)
            Spacer()
            Button(action: model.endEditing) {
                Text("lc.common.done".loc)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, HomeDesign.editButtonPadding)
                    .frame(minHeight: metrics.editButtonSize)
                    .homeGlass(.capsule, isInteractive: true)
                    .frame(minHeight: HomeDesign.minimumTouchSize)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, metrics.editControlsInset)
        .frame(width: metrics.size.width)
        .position(x: metrics.size.width / 2, y: metrics.editControlsCenterY)
    }
}
