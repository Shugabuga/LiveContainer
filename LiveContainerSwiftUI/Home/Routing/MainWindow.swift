//
//  MainWindow.swift
//  LiveContainerSwiftUI
//

import UIKit

/// Finds zContainer's main window, the one showing the Home Screen, for the
/// code that adds views to it or presents over it: multitasking's virtual
/// windows and their dock, and app windows launched from Objective-C. On iPad
/// several scenes can be connected at once, such as an app's own window or a
/// second zContainer window about to close, so the first connected scene could
/// be any of them. HomeRouter records the scene it accepts as the main window.
@objc final class MainWindow: NSObject {
    /// The scene HomeRouter accepted as the main window, until it disconnects.
    static weak var scene: UIWindowScene?

    /// The main window. Before HomeRouter has accepted one, it's the window of
    /// the scene in the foreground, or of any scene, which on iPhone is always
    /// the only one.
    @objc static var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let fallback = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let found = scene ?? fallback else {
            return nil
        }
        return found.keyWindow ?? found.windows.first
    }

    /// Whether a scene is the main window's, or could be: before HomeRouter
    /// has accepted a scene, any scene counts, so the first window to open
    /// isn't left out while it lays out.
    static func isMain(_ candidate: UIWindowScene?) -> Bool {
        guard let scene else {
            return true
        }
        return scene === candidate
    }
}
