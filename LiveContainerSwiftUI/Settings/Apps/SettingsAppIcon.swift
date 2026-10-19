//
//  SettingsAppIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's icon beside its row in Settings > Apps, as big as the colored
/// icons of the other rows: the icon the Home Screen shows, in its dark
/// version when the dark icons setting is on, with a hairline around it.
struct SettingsAppIcon: View {
    let app: LCAppModel

    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    @ScaledMetric(relativeTo: .body) private var size = SettingsDesign.iconSize

    var body: some View {
        // LCAppInfo keeps each icon in memory after drawing it once, and on
        // disk after the first launch, so reading it here is cheap.
        Image(uiImage: app.appInfo.iconIsDarkIcon(darkModeIcon) ?? UIImage())
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * SettingsDesign.iconCornerRatio))
            .overlay {
                RoundedRectangle(cornerRadius: size * SettingsDesign.iconCornerRatio)
                    .strokeBorder(.separator, lineWidth: SettingsDesign.iconOutlineWidth)
            }
            .accessibilityHidden(true)
    }
}
