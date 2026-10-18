//
//  HomeAppIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's icon as the Home Screen shows it: the icon IconServices drew for
/// the Home Screen, in its dark version when the dark icons setting is on,
/// with the app's name under it. While the app is being signed, the icon dims
/// and fills with iOS's progress pie.
struct HomeAppIcon: View {
    @ObservedObject var app: LCAppModel
    /// Where things go on this screen, for the icon's size.
    let metrics: HomeMetrics
    /// Whether the name shows under the icon. Icons in the dock have none.
    let showsLabel: Bool
    /// Marks the icon as the place its settings zoom out of.
    let zoomSource: HomeZoomSource

    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false

    var body: some View {
        VStack(spacing: HomeDesign.labelSpacing) {
            // LCAppInfo keeps each icon in memory after drawing it once, and on
            // disk after the first launch, so reading it here is cheap.
            Image(uiImage: app.appInfo.iconIsDarkIcon(darkModeIcon) ?? UIImage())
                .resizable()
                .scaledToFill()
                .frame(width: metrics.iconSize, height: metrics.iconSize)
                .clipShape(.rect(cornerRadius: metrics.iconCornerRadius))
                .overlay {
                    if app.isSigningInProgress {
                        HomeProgressPie(progress: app.signProgress, cornerRadius: metrics.iconCornerRadius)
                    }
                }
                .modifier(zoomSource)
                .accessibilityHidden(true)

            if showsLabel {
                HomeIconLabel(title: app.displayName)
            }
        }
    }
}
