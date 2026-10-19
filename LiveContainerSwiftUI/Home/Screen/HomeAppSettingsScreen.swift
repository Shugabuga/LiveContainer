//
//  HomeAppSettingsScreen.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's settings, opened from its long-press menu, with Done to go back
/// to the Home Screen and, as in Settings > Apps, Add to Home Screen.
struct HomeAppSettingsScreen: View {
    /// The app whose settings show.
    let app: LCAppModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LCAppSettingsView(model: app)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("lc.common.done".loc, action: close)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        AppShortcutMenu(app: app)
                    }
                }
        }
    }

    private func close() {
        dismiss()
    }
}
