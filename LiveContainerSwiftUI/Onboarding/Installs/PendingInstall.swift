//
//  PendingInstall.swift
//  LiveContainerSwiftUI
//

import Foundation

/// One app PendingInstallQueue is bringing in, from an install link or an
/// IPA, as Add Apps lists it. Each row watches its own app, so a download's
/// progress only redraws that row.
@MainActor
@Observable
final class PendingInstall: Identifiable {
    let id = UUID()
    /// Where the app came from.
    let source: PendingInstallSource

    /// How far it has come.
    private(set) var state: PendingInstallState
    /// How much of the IPA has downloaded, from 0 to 1.
    private(set) var downloadProgress = 0.0
    /// The app, once installed.
    private(set) var app: LCAppModel?

    /// The IPA on this iPhone, once it's there.
    @ObservationIgnored private(set) var file: URL?

    init(source: PendingInstallSource) {
        self.source = source
        switch source {
        case .link:
            state = .downloading
        case .openedFile(let url), .pickedFile(let url):
            state = .waiting
            file = url
        }
    }

    /// The app's name: its own once installed, until then what the source
    /// calls it.
    var name: String {
        app?.appInfo.displayName() ?? source.name
    }

    /// Notes how much of the IPA has downloaded.
    func downloadProgressed(_ fraction: Double) {
        downloadProgress = min(max(fraction, 0), 1)
    }

    /// Notes that the IPA has downloaded to `file`, ready to install.
    func downloaded(to file: URL) {
        self.file = file
        downloadProgress = 1
        state = .waiting
    }

    /// Notes that the install has started.
    func startInstalling() {
        state = .installing
    }

    /// Notes how the install ended: with the app it added, or nil when it
    /// added none.
    func finishInstalling(adding app: LCAppModel?) {
        self.app = app
        state = app == nil ? .notInstalled : .installed
    }

    /// Notes that the app couldn't come in, for this reason.
    func fail(_ reason: String) {
        state = .failed(reason)
    }
}
