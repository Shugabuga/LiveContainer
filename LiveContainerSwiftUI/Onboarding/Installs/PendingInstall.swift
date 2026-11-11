//
//  PendingInstall.swift
//  LiveContainerSwiftUI
//

import Foundation

/// One app PendingInstallQueue is bringing in, from an install link, an IPA
/// or Zeus, as Add Apps lists it. Each row watches its own app, so a
/// download's progress only redraws that row.
@MainActor
@Observable
final class PendingInstall: Identifiable {
    /// Also names the folder its IPA goes in, and its record.
    let id: UUID
    /// Where the app came from.
    let source: PendingInstallSource
    /// What to call the app until it's installed and its own name is known.
    let placeholderName: String

    /// How far it has come.
    private(set) var state: PendingInstallState
    /// How much of the IPA has downloaded, from 0 to 1.
    private(set) var downloadProgress = 0.0
    /// The app, once installed.
    private(set) var app: LCAppModel?

    /// The IPA on this iPhone, once it's there.
    @ObservationIgnored private(set) var file: URL?
    /// For an opened IPA, the bookmark that finds it again if zContainer
    /// closes before it's installed.
    let bookmark: Data?
    /// For an app from Zeus, the request Zeus left in the app group: the app
    /// Zeus says it sends, and the folder of the copy it replaces.
    let zeusRequest: ZeusRequest?

    /// - Parameters:
    ///   - id: The app's id, which one brought back after zContainer closed
    ///     keeps.
    ///   - source: Where the app came from.
    ///   - name: What to call it until it's installed, or nil for what the
    ///     source calls it.
    ///   - downloadedFile: A link's IPA, when it has downloaded already, or
    ///     the checked copy of an app from Zeus, or nil when it's still to
    ///     download or copy.
    ///   - bookmark: For an opened IPA, the bookmark that finds it again.
    ///   - zeusRequest: For an app from Zeus, the request Zeus left.
    init(
        id: UUID = UUID(),
        source: PendingInstallSource,
        name: String? = nil,
        downloadedFile: URL? = nil,
        bookmark: Data? = nil,
        zeusRequest: ZeusRequest? = nil
    ) {
        self.id = id
        self.source = source
        self.placeholderName = name ?? source.name
        self.bookmark = bookmark
        self.zeusRequest = zeusRequest
        switch source {
        case .link, .zeusRequest:
            file = downloadedFile
            state = downloadedFile == nil ? .downloading : .waiting
            downloadProgress = downloadedFile == nil ? 0 : 1
        case .openedFile(let url), .pickedFile(let url):
            file = url
            state = .waiting
        }
    }

    /// The app's name: its own once installed, until then what the source
    /// called it.
    var name: String {
        app?.appInfo.displayName() ?? placeholderName
    }

    /// Notes how much of the IPA has downloaded.
    func downloadProgressed(_ fraction: Double) {
        downloadProgress = min(max(fraction, 0), 1)
    }

    /// Notes that the IPA has downloaded, or been copied and checked, to
    /// `file`, ready to install.
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
