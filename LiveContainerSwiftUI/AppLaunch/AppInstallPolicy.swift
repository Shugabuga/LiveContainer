//
//  AppInstallPolicy.swift
//  LiveContainerSwiftUI
//

/// What an install does when the app is installed already.
enum AppInstallPolicy: Equatable, Sendable {
    /// Asks whether the app replaces one of the installed copies or installs
    /// as a new app, as installs from links, files and Files do.
    case ask

    /// Replaces the installed copy after a one-tap question, such as "Update
    /// Delta 1.2 to 1.3?", or installs the app as new without asking when no
    /// copy is installed. Only the requests Zeus leaves in the app group the
    /// two apps share install this way: no link makes one.
    ///
    /// `bundleIdentifier` is the app Zeus said it sent, and an IPA holding any
    /// other is turned away. `replacesFolder` is the folder of the copy to
    /// replace, when Zeus knows it.
    case fromZeus(bundleIdentifier: String, replacesFolder: String?)
}
