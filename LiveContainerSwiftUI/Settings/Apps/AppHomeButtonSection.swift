//
//  AppHomeButtonSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home Button switch in an app's settings. The button floats over the
/// app while it runs and brings back zContainer. TweakLoader draws it, so the
/// switch is off limits while TweakLoader is turned off for the app, and until
/// Settings > Home Screen turns the button on for apps, which it isn't at
/// first.
struct AppHomeButtonSection: View {
    /// The app whose settings show.
    @ObservedObject var model: LCAppModel

    /// Whether Settings > Home Screen lets apps show the Home button, which
    /// it doesn't until it's turned on there.
    @AppStorage("LCShowHomeButtonInApps") private var showsHomeButtonInApps = false

    var body: some View {
        let isTweakLoaderOff = model.uiDontInjectTweakLoader && model.uiDontLoadTweakLoader

        Section {
            Toggle("zc.settings.apps.homeButton".loc, isOn: $model.uiShowsHomeButton)
                .disabled(isTweakLoaderOff || !showsHomeButtonInApps)
        } footer: {
            Text(footer(isTweakLoaderOff: isTweakLoaderOff))
        }
    }

    /// Why the switch can't be used, when it can't, or else what it does.
    private func footer(isTweakLoaderOff: Bool) -> String {
        if !showsHomeButtonInApps {
            "zc.settings.apps.homeButtonOffEverywhere".loc
        } else if isTweakLoaderOff {
            "zc.settings.apps.homeButtonNeedsTweakLoader".loc
        } else {
            "zc.settings.apps.homeButtonFooter".loc
        }
    }
}
