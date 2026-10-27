//
//  HomeIconCell.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One icon on the pages or in the dock, and everything it does: a tap opens
/// it, a long press lifts it with its menu, and dragging it from there starts
/// edit mode with it in hand. In edit mode it jiggles while on screen, shows
/// its minus badge and can be held and dragged to a new place, or moved with
/// VoiceOver's actions.
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
    /// Whether the icon is on the page showing or in the dock. Only those
    /// jiggle in edit mode, so the pages off screen cost nothing each frame.
    let isOnScreen: Bool
    /// Whether the app's icon shows in its dark version, as the dark icons
    /// setting asks.
    let darkModeIcon: Bool
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isHeld = false

    var body: some View {
        Button(action: open) {
            HomeIconContent(
                item: item,
                app: app,
                metrics: metrics,
                showsLabel: showsLabel,
                darkModeIcon: darkModeIcon,
                zoomNamespace: zoomNamespace
            )
        }
        .buttonStyle(HomeIconButtonStyle())
        .accessibilityLabel(title)
        .homeIconMoveActions(for: item)
        .contentShape(.contextMenuPreview, HomeIconPreviewShape(iconSize: metrics.iconSize, cornerRadius: metrics.iconCornerRadius))
        .contextMenu {
            HomeIconMenu(item: item, app: app)
        }
        // Lets the icon be dragged out of its menu, which starts edit mode.
        // UIKit draws nothing under the finger: the Home Screen's own lifted
        // icon follows it, through HomeIconDropDelegate.
        .onDrag(menuDragItem) {
            Color.clear.frame(width: 1, height: 1)
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
                HomeMinusBadge(title: title, action: requestRemoval)
                    .position(x: iconLeft + HomeDesign.minusBadgeInset, y: HomeDesign.minusBadgeInset)
            }
        }
        .homeJiggle(isActive: model.isEditing && isOnScreen && !reduceMotion && !isLifted, seed: jiggleSeed)
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

    private func menuDragItem() -> NSItemProvider {
        model.offerMenuDrag(of: item)
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: HomeIconDropDelegate.iconType.identifier, visibility: .ownProcess) { completion in
            completion(Data(), nil)
            return nil
        }
        return provider
    }

    private func open() {
        model.open(item)
    }

    private func requestRemoval() {
        model.requestRemoval(of: item)
    }
}
