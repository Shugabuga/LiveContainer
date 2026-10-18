//
//  HomeSpringboard.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Everything on the Home Screen itself, laid out on the whole screen: the
/// pages, the dock, the search pill, edit mode's buttons, the icon being
/// dragged and the launch zoom. Positions come from HomeMetrics, in the
/// screen's coordinate space, which the drag gesture uses too.
struct HomeSpringboard: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        ZStack(alignment: .topLeading) {
            HomePagesView(metrics: metrics, zoomNamespace: zoomNamespace)

            HomeDock(metrics: metrics, zoomNamespace: zoomNamespace)

            HomeSearchPill(
                pageCount: model.pageCount,
                currentPage: model.page ?? 0,
                showsPageDots: model.showsPageDots || model.isEditing,
                action: model.openSearch
            )
            .position(metrics.pillCenter)

            if model.isEditing {
                HomeEditControls(metrics: metrics)
                    .transition(.opacity)
            }

            HomeLiftedIcon(metrics: metrics)

            if let zoom = model.launchZoom {
                HomeLaunchZoomView(zoom: zoom, metrics: metrics)
                    .id(zoom.id)
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .coordinateSpace(.named(HomeDesign.coordinateSpace))
        .onChange(of: metrics, initial: true) {
            model.metrics = metrics
        }
    }
}
