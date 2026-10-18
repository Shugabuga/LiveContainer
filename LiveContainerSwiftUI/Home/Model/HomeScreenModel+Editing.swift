//
//  HomeScreenModel+Editing.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Edit mode: jiggling icons that can be dragged to a new place, into or out
/// of the dock, or onto another page by holding them at the side of the
/// screen, and removed with their minus badge.
extension HomeScreenModel {
    /// Starts edit mode, as Edit Home Screen or a long press on the wallpaper do.
    func beginEditing() {
        guard !isEditing else {
            return
        }
        if isSearching {
            closeSearch()
        }
        withAnimation(HomeDesign.modeChange) {
            isEditing = true
        }
    }

    /// Ends edit mode, as Done or a tap on the wallpaper do. An icon still
    /// being dragged drops where it is.
    func endEditing() {
        guard isEditing else {
            return
        }
        if drag != nil {
            commitDrop()
        }
        withAnimation(HomeDesign.modeChange) {
            isEditing = false
        }
    }

    /// Ends edit mode when the wallpaper is tapped.
    func wallpaperTapped() {
        endEditing()
    }

    // MARK: Dragging

    /// Follows the finger moving an icon in edit mode. The first call picks the
    /// icon up; `start` is where the finger first touched it, which keeps the
    /// icon in the same spot under the finger. The other icons make room once
    /// the icon has hovered over a place for a moment, and holding it at the
    /// side of the screen turns the page.
    func dragChanged(_ item: HomeItem, finger: CGPoint, start: CGPoint) {
        guard isEditing, let metrics else {
            return
        }
        if drag == nil {
            guard let origin = layout.slot(of: item) else {
                return
            }
            let center = iconCenter(of: origin, in: layout, metrics: metrics)
            let grabOffset = CGSize(width: center.x - start.x, height: center.y - start.y)
            liftedIconCenter = center
            withAnimation(HomeDesign.reflow) {
                drag = HomeDrag(item: item, origin: origin, grabOffset: grabOffset, target: origin, preview: layout)
            }
        }
        guard let drag, drag.item == item else {
            return
        }
        let center = CGPoint(x: finger.x + drag.grabOffset.width, y: finger.y + drag.grabOffset.height)
        liftedIconCenter = center
        scheduleReflow(to: dropSlot(at: center, metrics: metrics))
        updatePageTurn(at: finger, metrics: metrics)
    }

    /// Drops the dragged icon where it is: it settles into its new place, and
    /// the layout is saved without the pages left empty.
    func dragEnded() {
        stopPageTurn()
        reflowTask?.cancel()
        reflowTask = nil
        pendingTarget = nil
        guard var drag, let metrics else {
            return
        }
        let target = dropSlot(at: liftedIconCenter, metrics: metrics)
        if target != drag.target {
            drag.target = target
            drag.preview = layout.moving(drag.item, to: target)
            withAnimation(HomeDesign.reflow) {
                self.drag = drag
            }
        }
        let destination = iconCenter(of: drag.target, in: drag.preview, metrics: metrics)
        withAnimation(HomeDesign.reflow) {
            liftedIconCenter = destination
        } completion: { [weak self] in
            self?.commitDrop()
        }
    }

    /// Puts the dragged icon down at once, where it was picked up.
    func cancelDrag() {
        stopPageTurn()
        reflowTask?.cancel()
        reflowTask = nil
        pendingTarget = nil
        drag = nil
    }

    /// Saves the dragged icon's new place and removes the pages it left empty,
    /// staying on the page that shows.
    func commitDrop() {
        guard let drag else {
            return
        }
        var final = drag.preview
        let currentPage = page ?? 0
        let emptyPagesBefore = final.pages.prefix(currentPage).count(where: \.isEmpty)
        final.removeEmptyPages()
        layout = final
        self.drag = nil
        page = min(max(currentPage - emptyPagesBefore, 0), final.pages.count - 1)
        HomeLayoutStorage.save(final)
    }

    /// Where an icon held at `center` drops: the place in the dock it is over,
    /// when the dock has room, or the place on the page showing nearest to it.
    /// A page has no gaps, so a place past its last icon means its end.
    private func dropSlot(at center: CGPoint, metrics: HomeMetrics) -> HomeSlot {
        guard let drag else {
            return .page(page ?? 0, index: 0)
        }
        var others = layout
        others.remove(drag.item)
        if metrics.dockContains(center) {
            guard others.dock.count < HomeLayout.dockCapacity else {
                return drag.target
            }
            return .dock(metrics.dockIndex(nearest: center, count: others.dock.count))
        }
        let page = page ?? 0
        let count = page < others.pages.count ? others.pages[page].count : 0
        return .page(page, index: min(metrics.gridIndex(nearest: center), count))
    }

    /// The center of the icon at a slot, on screen. A slot on a page is taken
    /// to be on the page showing.
    private func iconCenter(of slot: HomeSlot, in layout: HomeLayout, metrics: HomeMetrics) -> CGPoint {
        switch slot {
        case .page(_, let index):
            metrics.iconCenter(at: index)
        case .dock(let index):
            metrics.dockIconCenter(at: index, count: layout.dock.count)
        }
    }

    /// Makes room for the dragged icon at `target` once it has stayed there a
    /// moment.
    private func scheduleReflow(to target: HomeSlot) {
        guard target != pendingTarget else {
            return
        }
        pendingTarget = target
        reflowTask?.cancel()
        guard target != drag?.target else {
            return
        }
        reflowTask = Task { [weak self] in
            try? await Task.sleep(for: HomeDesign.reflowDelay)
            guard !Task.isCancelled else {
                return
            }
            self?.move(to: target)
        }
    }

    private func move(to target: HomeSlot) {
        guard var drag else {
            return
        }
        drag.target = target
        drag.preview = layout.moving(drag.item, to: target)
        withAnimation(HomeDesign.reflow) {
            self.drag = drag
        }
    }

    // MARK: Turning pages while dragging

    /// Starts turning pages while the finger holds the icon at the left or
    /// right side of the screen, and stops when it moves away.
    private func updatePageTurn(at finger: CGPoint, metrics: HomeMetrics) {
        let edge = HomeDesign.pageTurnEdge
        let direction = if metrics.dockContains(finger) {
            0
        } else if finger.x < edge {
            -1
        } else if finger.x > metrics.size.width - edge {
            1
        } else {
            0
        }
        guard direction != pageTurnDirection else {
            return
        }
        stopPageTurn()
        pageTurnDirection = direction
        guard direction != 0 else {
            return
        }
        pageTurnTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: HomeDesign.pageTurnDelay)
                guard !Task.isCancelled else {
                    return
                }
                self?.turnPage(by: direction)
            }
        }
    }

    private func stopPageTurn() {
        pageTurnTask?.cancel()
        pageTurnTask = nil
        pageTurnDirection = 0
    }

    /// Turns to the next or previous page with the dragged icon. Past the last
    /// page a new one opens, unless the last page holds only the dragged icon.
    private func turnPage(by direction: Int) {
        guard let drag, let metrics else {
            return
        }
        let next = (page ?? 0) + direction
        let pages = drag.preview.pages
        guard next >= 0 else {
            return
        }
        if next >= pages.count {
            let lastPageHasOtherIcons = pages.last?.contains { $0 != drag.item } ?? false
            guard next == pages.count, lastPageHasOtherIcons else {
                return
            }
        }

        var others = layout
        others.remove(drag.item)
        let count = next < others.pages.count ? others.pages[next].count : 0
        let target = HomeSlot.page(next, index: min(metrics.gridIndex(nearest: liftedIconCenter), count))
        reflowTask?.cancel()
        pendingTarget = target
        var turned = drag
        turned.target = target
        turned.preview = layout.moving(drag.item, to: target)
        withAnimation(HomeDesign.reflow) {
            self.drag = turned
            page = next
        }
    }

    // MARK: Removing

    /// Asks whether to delete the app behind an icon, as its minus badge does.
    func requestRemoval(of item: HomeItem) {
        guard case .app(let key) = item, let app = apps[key] else {
            return
        }
        pendingRemoval = app
    }

    /// Asks whether to delete an app, as Remove App does.
    func requestRemoval(of app: LCAppModel) {
        pendingRemoval = app
    }

    /// The question asked before an app is deleted.
    var removalTitle: String {
        "zc.home.deleteTitle %@".localizeWithFormat(pendingRemoval?.displayName ?? "")
    }

    /// Deletes an app, and its data unless the person chose to keep it.
    func removeApp(_ app: LCAppModel, deletingData: Bool) {
        Task {
            await coordinator.uninstall(app, deletingData: deletingData)
        }
    }

    /// Whether an icon shows a minus badge in edit mode. Settings can't be
    /// removed, and a shared app has to be made private again in its settings
    /// first, as in LiveContainer.
    func isRemovable(_ item: HomeItem) -> Bool {
        guard case .app(let key) = item, let app = apps[key] else {
            return false
        }
        return !app.uiIsShared
    }
}
