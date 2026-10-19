//
//  SystemAppearance.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Whether iOS is in Dark Mode. The Home Screen keeps zContainer's window
/// dark whatever the setting, so the window's own appearance can't tell; the
/// scene's still follows the system, and this follows the scene.
@MainActor
@Observable
final class SystemAppearance {
    /// Whether Dark Mode is on.
    private(set) var isDark = UITraitCollection.current.userInterfaceStyle == .dark

    @ObservationIgnored private var registration: (any UITraitChangeRegistration)?

    /// Starts following the appearance of the scene zContainer shows in. Only
    /// the first call does anything.
    func follow(_ scene: UIWindowScene) {
        guard registration == nil else {
            return
        }
        isDark = scene.traitCollection.userInterfaceStyle == .dark
        registration = scene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            self?.isDark = scene.traitCollection.userInterfaceStyle == .dark
        }
    }
}
