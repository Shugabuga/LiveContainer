//
//  AppIconChoice.swift
//  LiveContainerSwiftUI
//

import Foundation

/// zContainer's own icon on the iPhone's Home Screen, chosen in Settings > Home
/// Screen. zContainer starts with its own, the grid of apps on Zeus pink. OG is
/// the icon it had before, and the rest are the grid on the colors Zeus offers.
///
/// Every one but zContainer's own is an alternate icon iOS switches to by name,
/// which the build lists under CFBundleAlternateIcons from the files
/// Scripts/zc/art/render-icon.sh renders, under the same names.
enum AppIconChoice: CaseIterable, Identifiable {
    case zContainer
    case og
    case purple
    case blue
    case teal
    case green
    case orange
    case red
    case gold
    case mono
    case light

    var id: Self {
        self
    }

    /// The icon's name in Settings.
    var title: String {
        switch self {
        case .zContainer: "zc.appIcon.zContainer".loc
        case .og: "zc.appIcon.og".loc
        case .purple: "zc.appIcon.purple".loc
        case .blue: "zc.appIcon.blue".loc
        case .teal: "zc.appIcon.teal".loc
        case .green: "zc.appIcon.green".loc
        case .orange: "zc.appIcon.orange".loc
        case .red: "zc.appIcon.red".loc
        case .gold: "zc.appIcon.gold".loc
        case .mono: "zc.appIcon.mono".loc
        case .light: "zc.appIcon.light".loc
        }
    }

    /// The name iOS knows the icon by, or nil for zContainer's own.
    var alternateIconName: String? {
        switch self {
        case .zContainer: nil
        case .og: "OG"
        case .purple: "Purple"
        case .blue: "Blue"
        case .teal: "Teal"
        case .green: "Green"
        case .orange: "Orange"
        case .red: "Red"
        case .gold: "Gold"
        case .mono: "Mono"
        case .light: "Light"
        }
    }

    /// The icon's picture in the app, which the picker shows: the files iOS
    /// uses for it, loose in the app.
    var previewImageName: String {
        alternateIconName.map { "AppIcon\($0)60x60" } ?? "AppIcon60x60"
    }

    /// The choice in use, from the name iOS gives the icon it shows, nil when
    /// it's zContainer's own.
    init(alternateIconName name: String?) {
        self = Self.allCases.first { $0.alternateIconName == name } ?? .zContainer
    }
}
