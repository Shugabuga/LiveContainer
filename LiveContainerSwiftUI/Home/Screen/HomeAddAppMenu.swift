//
//  HomeAddAppMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The add button edit mode shows at the top left. It installs an app from an
/// IPA in Files or from a link, through the same install as everything else.
struct HomeAddAppMenu: View {
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
                .frame(width: HomeDesign.editButtonSize, height: HomeDesign.editButtonSize)
                .homeGlass(.circle, isInteractive: true)
                .frame(width: HomeDesign.minimumTouchSize, height: HomeDesign.minimumTouchSize)
                .contentShape(.circle)
        }
        .disabled(coordinator.isInstalling)
    }
}
