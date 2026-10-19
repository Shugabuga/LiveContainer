//
//  HomeDock.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The dock: icons without names on a glass panel at the bottom of the
/// screen, or on the trailing side on an iPhone in landscape, centered as on
/// iOS. An iPhone's dock holds up to four, an iPad's up to six, on glass only
/// as wide as its icons need, as on iPadOS. On iPhones with a Home button it
/// runs the full width, flush with the bottom. Not to be confused with
/// MultitaskDockView, the dock of multitasking windows.
struct HomeDock: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        let count = model.displayedLayout.dock.count
        let glass = metrics.dockFrame(holding: count)
        // A narrow iPad window shrinks a full dock's icons to fit.
        let iconMetrics = metrics.dockIconMetrics(count: count)

        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: glass.width, height: glass.height)
                .homeGlass(metrics.isDockFlush ? .edgeToEdge : .screenConcentric(fallbackRadius: metrics.dockCornerRadius))
                .contentShape(.rect)
                .position(x: glass.midX, y: glass.midY)
                .accessibilityHidden(true)

            ForEach(model.dockPlacements) { placement in
                HomeIconCell(
                    item: placement.item,
                    app: app(for: placement.item),
                    metrics: iconMetrics,
                    showsLabel: false,
                    isLifted: placement.isLifted,
                    isOnScreen: true,
                    darkModeIcon: darkModeIcon,
                    zoomNamespace: zoomNamespace
                )
                .position(position(of: placement.slot, count: count))
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .topLeading)
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else {
            return nil
        }
        return model.apps[key]
    }

    private func position(of slot: HomeSlot, count: Int) -> CGPoint {
        guard case .dock(let index) = slot else {
            return CGPoint(x: metrics.dockFrame.midX, y: metrics.dockFrame.midY)
        }
        return metrics.dockIconCenter(at: index, count: count)
    }
}
