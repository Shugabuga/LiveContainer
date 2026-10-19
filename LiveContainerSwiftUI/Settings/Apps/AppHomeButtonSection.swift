//
//  AppHomeButtonSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home Button switch in an app's settings. The button floats over the
/// app while it runs and brings back zContainer. TweakLoader draws it, so the
/// switch is off limits while TweakLoader is turned off for the app.
struct AppHomeButtonSection: View {
    /// The app whose settings show.
    @ObservedObject var model: LCAppModel

    var body: some View {
        let isTweakLoaderOff = model.uiDontInjectTweakLoader && model.uiDontLoadTweakLoader

        Section {
            Toggle("zc.settings.apps.homeButton".loc, isOn: $model.uiShowsHomeButton)
                .disabled(isTweakLoaderOff)
        } footer: {
            Text(isTweakLoaderOff ? "zc.settings.apps.homeButtonNeedsTweakLoader".loc : "zc.settings.apps.homeButtonFooter".loc)
        }
    }
}
