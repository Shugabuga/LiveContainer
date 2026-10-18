//
//  LCAppModel+HomeKey.swift
//  LiveContainerSwiftUI
//

import Foundation

extension LCAppModel {
    /// The key the Home Screen knows this app by: its bundle ID and the folder
    /// it is installed in, as `bundleId:relativeBundlePath`. It is the same key
    /// LiveContainer's custom sort order used, so that order carries over.
    /// Nil when the app's Info.plist has no bundle ID.
    var homeKey: String? {
        guard let bundleIdentifier = appInfo.bundleIdentifier(),
              let relativeBundlePath = appInfo.relativeBundlePath else {
            return nil
        }
        return "\(bundleIdentifier):\(relativeBundlePath)"
    }
}
