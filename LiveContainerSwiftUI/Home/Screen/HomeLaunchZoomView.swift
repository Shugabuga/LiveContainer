//
//  HomeLaunchZoomView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A tapped app opening: its icon grows from its place into a black screen,
/// the way iOS zooms an app open, just before zContainer turns into the app.
/// With Reduce Motion on, the screen fades to black instead. It tells the
/// model once the screen is covered, which lets the launch go ahead.
struct HomeLaunchZoomView: View {
    /// The icon the app opens from, and where it is.
    let zoom: HomeLaunchZoom
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpen = false

    var body: some View {
        let frame = isOpen || reduceMotion ? CGRect(origin: .zero, size: metrics.size) : zoom.iconFrame
        let iconScale = zoom.iconFrame.width > 0 ? frame.width / zoom.iconFrame.width : 1

        ZStack {
            Color.black
            HomeIconContent(item: zoom.item, app: app, metrics: metrics, showsLabel: false)
                .scaleEffect(reduceMotion ? 1 : iconScale)
                .opacity(isOpen || reduceMotion ? 0 : 1)
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(.rect(cornerRadius: isOpen ? 0 : metrics.iconCornerRadius))
        .position(x: frame.midX, y: frame.midY)
        .opacity(reduceMotion && !isOpen ? 0 : 1)
        .accessibilityHidden(true)
        .onAppear(perform: open)
    }

    private var app: LCAppModel? {
        guard case .app(let key) = zoom.item else {
            return nil
        }
        return model.apps[key]
    }

    private func open() {
        withAnimation(HomeDesign.launchZoom) {
            isOpen = true
        } completion: {
            model.launchZoomDidFinish()
        }
    }
}
