//
//  HomeIconCell.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One icon on the pages or in the dock, and everything it does: a tap opens
/// it, a long press lifts it with its menu, and in edit mode it jiggles, shows
/// its minus badge and can be held and dragged to a new place.
struct HomeIconCell: View {
    /// The icon.
    let item: HomeItem
    /// The app behind the icon, or nil for Settings.
    let app: LCAppModel?
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// Whether the name shows under the icon. Icons in the dock have none.
    let showsLabel: Bool
    /// Whether this icon is being dragged. Its view stays put and hidden while
    /// a copy follows the finger, so the drag gesture on it keeps going.
    let isLifted: Bool
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isHeld = false

    var body: some View {
        Button(action: open) {
            HomeIconContent(item: item, app: app, metrics: metrics, showsLabel: showsLabel, zoomNamespace: zoomNamespace)
        }
        .buttonStyle(HomeIconButtonStyle())
        .accessibilityLabel(title)
        .contentShape(.contextMenuPreview, HomeIconPreviewShape(iconSize: metrics.iconSize, cornerRadius: metrics.iconCornerRadius))
        .contextMenu {
            HomeIconMenu(item: item, app: app)
        }
        .highPriorityGesture(editDrag, including: model.isEditing ? .all : .subviews)
        .onChange(of: isHeld) { wasHeld, isHeld in
            if wasHeld && !isHeld {
                model.dragEnded()
            }
        }
        // The badge sits over the icon, outside the drag gesture, so a tap on
        // it isn't taken for the start of a drag.
        .overlay(alignment: .topLeading) {
            if model.isEditing && model.isRemovable(item) && !isLifted {
                HomeMinusBadge(action: requestRemoval)
                    .position(x: iconLeft + HomeDesign.minusBadgeInset, y: HomeDesign.minusBadgeInset)
            }
        }
        .homeJiggle(isActive: model.isEditing && !reduceMotion && !isLifted, seed: jiggleSeed)
        .opacity(isLifted ? 0 : 1)
        .accessibilityHidden(isLifted)
    }

    /// The icon's name, which VoiceOver reads even in the dock, where it
    /// doesn't show.
    private var title: String {
        switch item {
        case .settings:
            "lc.tabView.settings".loc
        case .app:
            app?.displayName ?? ""
        }
    }

    /// Where the icon's left edge is in this view.
    private var iconLeft: Double {
        showsLabel ? (metrics.cellWidth - metrics.iconSize) / 2 : 0
    }

    /// A number that stays the same for this icon, so it always jiggles its own way.
    private var jiggleSeed: Int {
        item.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    /// Holding an icon in edit mode for a moment picks it up; moving the finger
    /// then drags it. A quick swipe fails the hold, so it turns the page instead.
    private var editDrag: some Gesture {
        LongPressGesture(minimumDuration: HomeDesign.pickUpDelay, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(HomeDesign.coordinateSpace)))
            .updating($isHeld) { value, isHeld, _ in
                if case .second(true, _) = value {
                    isHeld = true
                }
            }
            .onChanged(dragChanged)
    }

    private func dragChanged(_ value: SequenceGesture<LongPressGesture, DragGesture>.Value) {
        guard case .second(true, let drag?) = value else {
            return
        }
        model.dragChanged(item, finger: drag.location, start: drag.startLocation)
    }

    private func open() {
        model.open(item)
    }

    private func requestRemoval() {
        model.requestRemoval(of: item)
    }
}
