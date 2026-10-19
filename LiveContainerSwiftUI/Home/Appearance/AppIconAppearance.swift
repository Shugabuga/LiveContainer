//
//  AppIconAppearance.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Works out whether apps' icons show in their dark versions, for every view
/// under it, and follows the system's appearance from the scene it shows in.
/// The answer is also saved as LiveContainer's dark icon setting, which its
/// multitasking windows read.
struct AppIconAppearance: ViewModifier {
    @AppStorage(HomeIconStyle.storageKey, store: LCUtils.appGroupUserDefault) private var style = HomeIconStyle.automatic
    @Environment(SystemAppearance.self) private var system

    func body(content: Content) -> some View {
        let prefersDark = style.prefersDarkIcons(systemIsDark: system.isDark)

        content
            .environment(\.prefersDarkAppIcons, prefersDark)
            .onAppear(perform: followScene)
            .onChange(of: prefersDark, initial: true) {
                LCUtils.appGroupUserDefault.set(prefersDark, forKey: Self.liveContainerKey)
            }
    }

    /// LiveContainer's own dark icon setting.
    private static let liveContainerKey = "darkModeIcon"

    private func followScene() {
        let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
        if let scene {
            system.follow(scene)
        }
    }
}

extension View {
    /// Picks the light or dark versions of apps' icons for this view and the
    /// views under it. Apply it once, to the main window's root.
    func appIconAppearance() -> some View {
        modifier(AppIconAppearance())
    }
}
