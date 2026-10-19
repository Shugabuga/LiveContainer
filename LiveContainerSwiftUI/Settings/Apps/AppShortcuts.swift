//
//  AppShortcuts.swift
//  LiveContainerSwiftUI
//

import UIKit

/// Makes what opens an app inside zContainer from the iPhone's own Home
/// Screen: its launch link, its icon, and a web clip profile. Icons have
/// zContainer's frame around them when Frame Shortcut Icons is on.
@MainActor
enum AppShortcuts {
    /// The link that opens the app, in the container it opens in by default.
    static func launchLink(for app: LCAppModel) -> String? {
        guard let scheme = LCSharedUtils.hostAppUrlScheme(), let bundleName = app.appInfo.relativeBundlePath else {
            return nil
        }
        var link = "\(scheme)://livecontainer-launch?bundle-name=\(bundleName)"
        if let folderName = app.uiSelectedContainer?.folderName {
            link += "&container-folder-name=\(folderName)"
        }
        return link
    }

    /// The app's icon as a PNG, drawn in the style asked for.
    static func iconFile(for app: LCAppModel, style: GeneratedIconStyle) throws -> AppIconFile {
        guard let png = app.appInfo.generateLiveContainerWrappedIcon(with: style)?.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return AppIconFile(png: png)
    }

    /// A configuration profile adding a web clip that opens the app, as a
    /// data link Safari offers to download, which Settings then installs.
    static func webClipLink(for app: LCAppModel, style: GeneratedIconStyle) throws -> URL {
        guard let profile = app.appInfo.generateWebClipConfig(
            withContainerId: app.uiSelectedContainer?.folderName,
            iconStyle: style
        ) else {
            throw CocoaError(.propertyListWriteInvalid)
        }
        let data = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
        guard let link = URL(string: "data:application/x-apple-aspen-config;base64,\(data.base64EncodedString())") else {
            throw CocoaError(.propertyListWriteInvalid)
        }
        return link
    }

    /// The name Files suggests for the icon.
    static func iconFileName(for app: LCAppModel) -> String {
        let name = app.displayName.replacing("/", with: "_")
        return "zc.settings.shortcut.iconFileName %@".localizeWithFormat(name)
    }
}
