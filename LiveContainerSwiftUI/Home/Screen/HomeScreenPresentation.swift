//
//  HomeScreenPresentation.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Opens Settings or an app's settings over the Home Screen. On iOS 18 and
/// later the screen zooms out of its icon and covers the Home Screen, the way
/// an app opens, and swiping down closes it again. iOS 17 opens it as a sheet.
struct HomeScreenPresentation: ViewModifier {
    @Bindable var model: HomeScreenModel
    /// The namespace the icons are marked in as zoom sources.
    let zoomNamespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.fullScreenCover(item: $model.presentedScreen, onDismiss: model.presentedScreenDidClose) { screen in
                HomePresentedScreenView(screen: screen)
                    .navigationTransition(.zoom(sourceID: screen.id, in: zoomNamespace))
            }
        } else {
            content.sheet(item: $model.presentedScreen, onDismiss: model.presentedScreenDidClose) { screen in
                HomePresentedScreenView(screen: screen)
            }
        }
    }
}
