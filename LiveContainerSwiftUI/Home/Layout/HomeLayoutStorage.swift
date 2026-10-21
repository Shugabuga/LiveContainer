//
//  HomeLayoutStorage.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Saves the Home Screen layout as JSON in the app group's defaults, along
/// with the page to come back to after an app. Without an app group they fall
/// back to the "Unknown" suite in zContainer's own preferences, and
/// LCSharedUtils copies the layout into the group once zContainer has one.
enum HomeLayoutStorage {
    /// The defaults key the layout is saved under.
    private static let layoutKey = "ZCHomeScreenLayout"
    /// The page an app was opened from. zContainer quits on the way into the
    /// app, so its state can't be restored any other way.
    private static let returnPageKey = "ZCHomeScreenPage"
    /// LiveContainer's custom app order, which the share extension still reads
    /// to list the apps.
    private static let customOrderKey = "LCCustomSortOrder"
    /// LiveContainer's sort setting, which tells the share extension to use
    /// the custom order.
    private static let sortTypeKey = "LCAppSortType"

    private static var defaults: UserDefaults {
        LCUtils.appGroupUserDefault
    }

    /// The saved layout, or nil on the first launch or when it can't be read.
    static func load() -> HomeLayout? {
        guard let data = defaults.data(forKey: layoutKey) else {
            return nil
        }
        return try? JSONDecoder().decode(HomeLayout.self, from: data)
    }

    /// Saves the layout. The apps' order is also written as LiveContainer's
    /// custom order, so the share extension lists them as the Home Screen does.
    static func save(_ layout: HomeLayout) {
        guard let data = try? JSONEncoder().encode(layout) else {
            return
        }
        defaults.set(data, forKey: layoutKey)
        defaults.set(layout.appKeysInOrder, forKey: customOrderKey)
        defaults.set("custom", forKey: sortTypeKey)
    }

    /// Saves the page an app is opened from, for when zContainer comes back.
    static func saveReturnPage(_ page: Int) {
        defaults.set(page, forKey: returnPageKey)
    }

    /// The page an app was opened from, once: it is forgotten after reading,
    /// so only the launch that comes back from an app opens on it. 0 when no
    /// app was opened.
    static func takeReturnPage() -> Int {
        let page = defaults.integer(forKey: returnPageKey)
        defaults.removeObject(forKey: returnPageKey)
        return max(page, 0)
    }

    /// The custom order LiveContainer's app list saved, which a first launch
    /// starts from. Empty when there is none.
    static func legacyCustomOrder() -> [String] {
        defaults.array(forKey: customOrderKey) as? [String] ?? []
    }
}
