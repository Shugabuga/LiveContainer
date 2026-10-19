//
//  AppShortcutKind.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What the Add to Home Screen menu makes from an app's icon, which waits
/// for the icon style to be chosen on iOS 18 and later.
enum AppShortcutKind: Equatable {
    /// A PNG of the icon, saved to Files, to use with a Shortcuts shortcut.
    case iconFile
    /// A web clip on the iPhone's Home Screen that opens the app in zContainer.
    case webClip
}
