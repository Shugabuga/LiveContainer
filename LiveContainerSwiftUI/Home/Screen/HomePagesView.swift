//
//  HomePagesView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The pages of icons, swiped through one screen at a time. Each page is a
/// screen-wide stop for the paging scroll view; the icons of every page sit in
/// one layer over the stops, so an icon dragged onto another page stays the
/// same view and its drag goes on.
struct HomePagesView: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let pageCount = model.pageCount

        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(0..<pageCount, id: \.self) { _ in
                    Color.clear
                        .frame(width: metrics.size.width, height: metrics.size.height)
                }
            }
            .scrollTargetLayout()
            .background {
                HomeWallpaper()
            }
            .overlay(alignment: .topLeading) {
                HomePageIcons(metrics: metrics, pageCount: pageCount, zoomNamespace: zoomNamespace)
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $model.page)
        .scrollDisabled(model.drag != nil)
        .modifier(HomeScrollPhaseTracking(model: model))
        // HomeMetrics places the icons from the screen's top left corner, so
        // the pages fill the screen without the usual safe area margins.
        .ignoresSafeArea()
    }
}
