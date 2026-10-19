//
//  HomeAddAppMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The add button edit mode shows at the top left. It installs an app from an
/// IPA in Files or from a link, through the same install as everything else.
struct HomeAddAppMenu: View {
    /// The button's width and height, which HomeMetrics picks for the screen.
    let size: Double

    @Environment(HomeScreenModel.self) private var model
    @Environment(AppLaunchCoordinator.self) private var coordinator

    var body: some View {
        Menu {
            Button("lc.appList.installFromIpa".loc, systemImage: "doc.badge.plus", action: model.chooseIPA)
            Button("lc.appList.installFromUrl".loc, systemImage: "link.badge.plus", action: model.askForInstallURL)
        } label: {
            Label("zc.home.addApp".loc, systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .homeGlass(.circle, isInteractive: true)
                .frame(width: HomeDesign.minimumTouchSize, height: HomeDesign.minimumTouchSize)
                .contentShape(.circle)
        }
        .disabled(coordinator.isInstalling)
    }
}
