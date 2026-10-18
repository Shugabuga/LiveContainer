//
//  HomeLayout.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where every icon sits: the pages, each holding up to 24 icons in order, and
/// the dock, holding up to 4. Like iOS, a page has no gaps; icons fill it from
/// the top left. HomeLayoutStorage saves it as JSON.
struct HomeLayout: Codable, Equatable, Sendable {
    /// How many icons fit on a page: 4 columns by 6 rows, or 6 by 4 in landscape.
    static let iconsPerPage = 24
    /// How many icons fit in the dock.
    static let dockCapacity = 4

    /// The pages, left to right. There is always at least one, even if empty.
    var pages: [[HomeItem]]
    /// The dock's icons, left to right.
    var dock: [HomeItem]

    /// A layout with one empty page and Settings in the dock, which is where a
    /// first launch starts before the apps are added.
    init(pages: [[HomeItem]] = [[]], dock: [HomeItem] = [.settings]) {
        self.pages = pages.isEmpty ? [[]] : pages
        self.dock = dock
    }

    /// The apps in Home Screen order: page by page, then the dock.
    var appKeysInOrder: [String] {
        (pages.flatMap { $0 } + dock).compactMap { item in
            if case .app(let key) = item {
                key
            } else {
                nil
            }
        }
    }

    /// Where an item is, or nil when it isn't in the layout.
    func slot(of item: HomeItem) -> HomeSlot? {
        if let index = dock.firstIndex(of: item) {
            return .dock(index)
        }
        for (page, items) in pages.enumerated() {
            if let index = items.firstIndex(of: item) {
                return .page(page, index: index)
            }
        }
        return nil
    }

    /// The slot a new app takes: the first free one on the last page, or the
    /// first on a new page when the last page is full.
    var nextFreeSlot: HomeSlot {
        let lastPage = max(pages.count - 1, 0)
        let count = pages.last?.count ?? 0
        if count < Self.iconsPerPage {
            return .page(lastPage, index: count)
        }
        return .page(lastPage + 1, index: 0)
    }

    /// Adds an item where iOS puts a new app: `nextFreeSlot`.
    mutating func append(_ item: HomeItem) {
        insert(item, at: nextFreeSlot)
    }

    /// Takes an item out, wherever it is. The page it leaves can end up empty;
    /// `removeEmptyPages()` tidies that up.
    mutating func remove(_ item: HomeItem) {
        dock.removeAll { $0 == item }
        for page in pages.indices {
            pages[page].removeAll { $0 == item }
        }
    }

    /// Puts an item at a slot, moving the icons after it along. A page that
    /// overflows pushes its last icon onto the start of the next page, adding
    /// one when needed. A position past the end of a page or of the dock means
    /// its end. Returns false, leaving the layout as it was, when the dock is
    /// full.
    @discardableResult
    mutating func insert(_ item: HomeItem, at slot: HomeSlot) -> Bool {
        switch slot {
        case .dock(let index):
            guard dock.count < Self.dockCapacity else {
                return false
            }
            dock.insert(item, at: min(max(index, 0), dock.count))
        case .page(let page, let index):
            let page = max(page, 0)
            while pages.count <= page {
                pages.append([])
            }
            pages[page].insert(item, at: min(max(index, 0), pages[page].count))
            spill(from: page)
        }
        return true
    }

    /// The layout with an item moved to a slot, as it would look if dropped
    /// there. Empty pages stay, so the pages don't shift under the finger while
    /// the item is being dragged.
    func moving(_ item: HomeItem, to slot: HomeSlot) -> HomeLayout {
        var moved = self
        moved.remove(item)
        if !moved.insert(item, at: slot), let origin = self.slot(of: item) {
            // The dock was full: leave the item where it was.
            moved.insert(item, at: origin)
        }
        return moved
    }

    /// Removes the pages that have no icons left, keeping at least one page.
    mutating func removeEmptyPages() {
        pages.removeAll { $0.isEmpty }
        if pages.isEmpty {
            pages = [[]]
        }
    }

    /// Brings the layout in line with the apps the Home Screen shows. Apps that
    /// were removed or hidden leave their slot, apps not yet placed take the
    /// next free slot in the order given, and Settings comes back if it went
    /// missing. Icons listed twice keep their first place.
    mutating func reconcile(withAppKeys keys: [String]) {
        let shown = Set(keys)
        var placed = Set<HomeItem>()
        func keeps(_ item: HomeItem) -> Bool {
            let wanted = switch item {
            case .app(let key):
                shown.contains(key)
            case .settings:
                true
            }
            return wanted && placed.insert(item).inserted
        }
        dock = dock.filter(keeps)
        for page in pages.indices {
            pages[page] = pages[page].filter(keeps)
        }

        // A layout saved by a different build could hold more than fits.
        while dock.count > Self.dockCapacity {
            let extra = dock.removeLast()
            append(extra)
        }
        var page = 0
        while page < pages.count {
            spill(from: page)
            page += 1
        }

        removeEmptyPages()
        if !placed.contains(.settings) {
            if dock.count < Self.dockCapacity {
                dock.append(.settings)
            } else {
                append(.settings)
            }
        }
        for key in keys where placed.insert(.app(key)).inserted {
            append(.app(key))
        }
    }

    /// Moves a page's overflow onto the following pages, one icon at a time.
    private mutating func spill(from page: Int) {
        var page = page
        while page < pages.count, pages[page].count > Self.iconsPerPage {
            let overflow = pages[page].removeLast()
            if page + 1 == pages.count {
                pages.append([])
            }
            pages[page + 1].insert(overflow, at: 0)
            page += 1
        }
    }
}
