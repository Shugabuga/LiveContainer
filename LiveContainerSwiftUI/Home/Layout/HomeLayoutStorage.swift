//
//  HomeLayoutStorage.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Saves the Home Screen layout as JSON in the app group's defaults, or the
/// standard defaults when zContainer has no app group.
enum HomeLayoutStorage {
    /// The defaults key the layout is saved under.
    private static let layoutKey = "ZCHomeScreenLayout"
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

    /// The custom order LiveContainer's app list saved, which a first launch
    /// starts from. Empty when there is none.
    static func legacyCustomOrder() -> [String] {
        defaults.array(forKey: customOrderKey) as? [String] ?? []
    }
}
