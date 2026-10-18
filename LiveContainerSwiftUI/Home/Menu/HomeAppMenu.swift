//
//  HomeAppMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's long-press menu: the container to run it in when it has several,
/// Open in New Container and its settings; then locking it behind Face ID,
/// Edit Home Screen, and Remove App.
struct HomeAppMenu: View {
    @ObservedObject var app: LCAppModel
    /// Whether Edit Home Screen shows, which it doesn't for apps found in search.
    let showsEditHomeScreen: Bool

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        if app.uiContainers.count > 1 {
            Picker(selection: $app.uiSelectedContainer) {
                ForEach(app.uiContainers, id: \.self) { container in
                    Text(verbatim: container.name)
                        .tag(Optional(container))
                }
            } label: {
                Label("lc.common.container".loc, systemImage: "shippingbox")
            }
            .pickerStyle(.menu)
        }

        Section {
            Button("zc.home.openInNewContainer".loc, systemImage: "plus.square.on.square", action: openInNewContainer)
            Button("zc.home.appSettings".loc, systemImage: "gearshape", action: showSettings)
        }

        Section {
            HomeLockMenu(app: app)
            if showsEditHomeScreen {
                Button("zc.home.editHomeScreen".loc, systemImage: "apps.iphone", action: model.beginEditing)
            }
            if !app.uiIsShared {
                Button("zc.home.removeApp".loc, systemImage: "minus.circle", role: .destructive, action: requestRemoval)
            }
        }
    }

    private func openInNewContainer() {
        model.openInNewContainer(app)
    }

    private func showSettings() {
        model.showSettings(for: app)
    }

    private func requestRemoval() {
        model.requestRemoval(of: app)
    }
}
