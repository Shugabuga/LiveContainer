//
//  HomeLiftedIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The copy of the dragged icon that follows the finger in edit mode, a
/// little larger than the others and without its name, as on iOS.
struct HomeLiftedIcon: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        if let drag = model.drag {
            HomeIconContent(item: drag.item, app: app(for: drag.item), metrics: metrics, showsLabel: false, darkModeIcon: darkModeIcon)
                .scaleEffect(HomeDesign.liftedScale)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                .position(model.liftedIconCenter)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else {
            return nil
        }
        return model.apps[key]
    }
}
