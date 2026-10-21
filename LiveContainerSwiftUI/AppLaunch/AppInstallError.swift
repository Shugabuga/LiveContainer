//
//  AppInstallError.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Why an install stopped before it changed anything.
enum AppInstallError: LocalizedError, Equatable {
    /// The app to replace is open, in zContainer, in a multitasking window or
    /// in another zContainer. Replacing it would pull its files from under it.
    case running(appName: String)
    /// Zeus said it sent one app, and the IPA holds another.
    case bundleMismatch(expected: String, found: String)
    /// The IPA's bundle ID can't name a folder: it's empty or too long, holds
    /// a slash, a colon or a NUL, or starts with a dot.
    case invalidBundleIdentifier

    var errorDescription: String? {
        switch self {
        case .running(let appName):
            "zc.update.running %@".localizeWithFormat(appName)
        case let .bundleMismatch(expected, found):
            "zc.zeusRequest.mismatch %@ %@".localizeWithFormat(expected, found)
        case .invalidBundleIdentifier:
            "lc.appList.infoPlistCannotReadError".loc
        }
    }
}
