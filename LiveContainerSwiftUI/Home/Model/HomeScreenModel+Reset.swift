//
//  HomeScreenModel+Reset.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > General > Reset > Reset Home Screen Layout.
extension HomeScreenModel {
    /// Lays the Home Screen out again the way a first launch with no saved
    /// order does: Settings alone in the dock, and the apps on the pages in
    /// the order they were added. The first page shows when it's done.
    func resetLayout() {
        if isEditing {
            endEditing()
        }
        let fresh = HomeLayout.firstLaunch(apps: sharedModel.apps, customOrder: [])
        layout = fresh
        page = 0
        HomeLayoutStorage.save(fresh)
    }
}
