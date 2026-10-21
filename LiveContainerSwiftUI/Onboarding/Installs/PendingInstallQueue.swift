//
//  PendingInstallQueue.swift
//  LiveContainerSwiftUI
//

import Combine
import Foundation

/// The apps on their way into zContainer that mustn't be lost: those sent
/// while onboarding shows, install links that arrive while another app
/// installs, and every app Zeus leaves in the app group the two apps share.
///
/// An install link starts downloading the moment it arrives, whatever step
/// is showing: a one-time `http://127.0.0.1` link from Zeus only answers for
/// about a minute. An app from Zeus is copied out of the app group just as
/// early, one at a time in the order they arrived, and each copy checked
/// against the size and SHA-256 Zeus gave. Installing waits until onboarding
/// reaches Add Apps, since the steps before it set up and check the
/// certificate the apps are signed with, and the Check Setup step signs a
/// test library that an install's signing shouldn't run beside. Apps then
/// install one at a time, as every install does, each through
/// AppLaunchCoordinator. An app from Zeus replaces the copy installed after
/// a one-tap question, such as "Update Delta 1.2 to 1.3?", and how it ended
/// is written back to the app group for Zeus.
///
/// Apps still on their way in when onboarding closes go on in the same way,
/// and links that arrive meanwhile join them rather than being turned away
/// by the install running.
///
/// The apps outlast zContainer closing, as it does when Zeus signs it again
/// or iOS ends it while the person is in Zeus: PendingInstallStore keeps
/// their IPAs and writes them down whenever one changes, and the next launch
/// brings back the ones still to install, under Add Apps again or
/// installing at once when onboarding doesn't show.
@MainActor
@Observable
final class PendingInstallQueue {
    /// The apps, in the order they arrived.
    private(set) var items: [PendingInstall] = []
    /// Whether installs wait, as they do until onboarding reaches Add Apps.
    /// Downloads never wait.
    private(set) var holdsInstalls: Bool

    /// Whether a failure shows as an alert, as it does while no list shows
    /// it: once onboarding has closed.
    @ObservationIgnored private var reportsFailures: Bool
    /// Whether one of the apps is installing.
    @ObservationIgnored private var isInstalling = false
    /// The copy out of the app group that started last, which the next one
    /// waits for, so the apps from Zeus don't all hash at once.
    @ObservationIgnored private var lastCopy: Task<Void, Never>?
    @ObservationIgnored private let coordinator: AppLaunchCoordinator

    /// Brings back the apps that were still on their way in when zContainer
    /// last closed. Downloads that hadn't finished start again; the rest
    /// install now, or once onboarding reaches Add Apps.
    /// - Parameter holdsForOnboarding: Whether onboarding shows from the
    ///   start, so installs wait for it.
    init(coordinator: AppLaunchCoordinator, holdsForOnboarding: Bool) {
        self.coordinator = coordinator
        holdsInstalls = holdsForOnboarding
        reportsFailures = !holdsForOnboarding
        items = PendingInstallStore.restore()
        for item in items where item.state == .downloading {
            switch item.source {
            case .link(let url):
                Task {
                    await download(item, from: url)
                }
            case .zeusRequest:
                if let request = item.zeusRequest {
                    startCopy(item, of: request)
                }
            case .openedFile, .pickedFile:
                break
            }
        }
        installNext()
    }

    /// Whether any app is still on its way in.
    var hasUnfinishedItems: Bool {
        items.contains { !$0.state.isFinished }
    }

    /// The names of the apps that were installed.
    var installedNames: [String] {
        items.filter { $0.state == .installed }.map(\.name)
    }

    /// How many apps were installed, which goes up by one with each.
    var installedCount: Int {
        items.count(where: { $0.state == .installed })
    }

    // MARK: Receiving

    /// Takes the IPA an install link points at: a web address, which starts
    /// downloading now, or a file opened with zContainer. Returns false for
    /// any other kind of link, which AppLaunchCoordinator handles as usual.
    func receive(address: String) -> Bool {
        guard let url = URL(string: address) else {
            return false
        }
        if url.isFileURL {
            add(PendingInstall(source: .openedFile(url), bookmark: Self.bookmark(forOpenedFile: url)))
            return true
        }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return false
        }
        let item = PendingInstall(source: .link(url))
        add(item)
        Task {
            await download(item, from: url)
        }
        return true
    }

    /// Takes an app Zeus left in the app group the two apps share, once
    /// ZeusGroup has read and checked its request. The app is copied out of
    /// the group once the apps before it are, and installs once its turn
    /// comes. A request that sends no app, such as Zeus's certificate, is
    /// left alone. A request already on its way in isn't taken twice.
    func receive(zeusRequest request: ZeusRequest) {
        guard request.kind == .app else {
            return
        }
        let isOnItsWay = items.contains { $0.source == .zeusRequest(request.id) && !$0.state.isFinished }
        guard !isOnItsWay else {
            return
        }
        // A name of only spaces would leave the app's row blank.
        let name = request.name.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        let item = PendingInstall(source: .zeusRequest(request.id), name: name, zeusRequest: request)
        add(item)
        startCopy(item, of: request)
    }

    /// Takes an IPA picked in Files, which Files copied for zContainer.
    func add(pickedFile url: URL) {
        let id = UUID()
        // Files copies into the temporary folder, which iOS may empty while
        // zContainer is closed, so the copy moves in beside the downloads.
        let file = (try? PendingInstallStore.moveIn(url, for: id)) ?? url
        add(PendingInstall(id: id, source: .pickedFile(file)))
    }

    private func add(_ item: PendingInstall) {
        // Once onboarding has closed, no list shows the apps that are done
        // coming in, so they're let go rather than kept until it opens again.
        if reportsFailures {
            items.removeAll { $0.state.isFinished }
        }
        items.append(item)
        saveItems()
        installNext()
    }

    /// A bookmark that finds an opened IPA again if zContainer closes before
    /// it's installed, and that installing it reads it through. One shared
    /// to zContainer may be reachable only through the share extension's
    /// bookmark, when it names this file, which the item keeps its own copy
    /// of, since the next file shared replaces it.
    private static func bookmark(forOpenedFile url: URL) -> Data? {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        if FileManager.default.isReadableFile(atPath: url.path), let bookmark = LCUtils.bookmark(for: url) {
            return bookmark
        }
        return InstallLinkPolicy.sharedFileBookmark(for: url)?.bookmark
    }

    /// Where an opened IPA can be read: where it is, when zContainer can
    /// read it there, as it can a file in the Inbox, or else where its own
    /// security-scoped bookmark finds it, rather than the share extension's,
    /// which names only the file shared last.
    private static func reachableFile(_ file: URL, bookmark: Data?) -> URL {
        guard !FileManager.default.isReadableFile(atPath: file.path), let bookmark else {
            return file
        }
        return (try? LCUtils.resolveSecurityScopedBookmark(bookmark)) ?? file
    }

    // MARK: Onboarding

    /// Makes installs wait, and keeps failures for the list, as onboarding
    /// opens. Apps that finished coming in since it last closed aren't
    /// listed again.
    func holdForOnboarding() {
        holdsInstalls = true
        reportsFailures = false
        items.removeAll { $0.state.isFinished }
    }

    /// Lets the apps install, as onboarding reaches Add Apps.
    func startInstalling() {
        holdsInstalls = false
        installNext()
    }

    /// Lets the apps still coming in carry on after onboarding closes, with
    /// failures shown as alerts from now on. The list stays as it is while
    /// the last step fades away; `holdForOnboarding()` clears it.
    func onboardingDidClose() {
        reportsFailures = true
        startInstalling()
    }

    // MARK: Downloading

    /// Downloads a link's IPA into the app's own folder, the way installing
    /// from a link always does, with the progress on the app's row.
    private func download(_ item: PendingInstall, from url: URL) async {
        let downloader = DownloadHelper()
        // DownloadHelper reports its progress on the main queue.
        let progress = downloader.$downloadProgress.sink { [weak item] fraction in
            MainActor.assumeIsolated {
                item?.downloadProgressed(Double(fraction))
            }
        }
        defer { progress.cancel() }

        do {
            let folder = try PendingInstallStore.makeFolder(for: item.id)
            let destination = folder.appending(path: PendingInstallSource.downloadName(for: url), directoryHint: .notDirectory)
            try await downloader.download(url: url, to: destination)
            item.downloaded(to: destination)
            saveItems()
        } catch {
            PendingInstallStore.removeFolder(for: item.id)
            fail(item, because: "zc.onboarding.apps.downloadFailed %@".localizeWithFormat(error.localizedDescription))
        }
        installNext()
    }

    /// Copies an app from Zeus out of the app group once the copy before it
    /// is done. Each copy reads the whole IPA to check it, and installs go
    /// one at a time anyway, so copying them all at once would only keep
    /// the first install waiting behind the others.
    private func startCopy(_ item: PendingInstall, of request: ZeusRequest) {
        let previous = lastCopy
        lastCopy = Task {
            await previous?.value
            await copy(item, of: request)
        }
    }

    /// Copies the app a request from Zeus sends into the app's own folder,
    /// and checks the copy against the size and SHA-256 Zeus gave. When it
    /// can't be copied, or the copy doesn't match, the app fails and Zeus is
    /// told why: damaged for a copy that doesn't match, else unreadable,
    /// with the system's own words when the copy itself failed, as on a full
    /// disk.
    private func copy(_ item: PendingInstall, of request: ZeusRequest) async {
        do {
            let folder = try PendingInstallStore.makeFolder(for: item.id)
            let copy = try await ZeusGroup.copyAppPayload(of: request, into: folder)
            item.downloaded(to: copy)
            saveItems()
        } catch {
            PendingInstallStore.removeFolder(for: item.id)
            let groupError = error as? ZeusGroupError
            let reason = groupError == nil ? error.localizedDescription : "zc.zeusRequest.unreadable".loc
            fail(item, because: reason)
            let failure: ZeusRequestFailure = groupError == .damaged ? .damaged : .unreadable
            ZeusGroup.writeResult(ZeusRequestResult(id: request.id, outcome: .failed, failure: failure, message: reason))
        }
        installNext()
    }

    // MARK: Installing

    /// Installs the first app that's ready, unless installs wait or one is
    /// installing, then the next, until none is ready.
    private func installNext() {
        guard !holdsInstalls, !isInstalling,
              let item = items.first(where: { $0.state == .waiting }) else {
            return
        }
        isInstalling = true
        Task {
            await install(item)
            isInstalling = false
            installNext()
        }
    }

    /// Installs an app once AppLaunchCoordinator is free, as it may not be
    /// once onboarding has closed, since it installs one app at a time. How
    /// an app from Zeus ended is written back for Zeus.
    private func install(_ item: PendingInstall) async {
        guard let storedFile = item.file else {
            item.finishInstalling(adding: nil)
            saveItems()
            if let request = item.zeusRequest {
                ZeusGroup.writeResult(ZeusRequestResult(id: request.id, outcome: .cancelled))
            }
            return
        }
        await coordinator.waitForInstallTurn()
        // Onboarding may have opened again while this app waited for its turn.
        guard !holdsInstalls else {
            return
        }
        item.startInstalling()
        saveItems()

        // An opened IPA may lie outside zContainer, as one shared to it does,
        // and only opens with access granted. It's found through its own
        // bookmark, since the share extension's names only the file shared last.
        let file = item.source.isOwnCopy ? storedFile : Self.reachableFile(storedFile, bookmark: item.bookmark)
        let isAccessing = !item.source.isOwnCopy && file.startAccessingSecurityScopedResource()
        do {
            let outcome = try await coordinator.installReceivedIPA(
                at: file,
                isOwnCopy: item.source.isOwnCopy,
                policy: Self.policy(for: item)
            )
            item.finishInstalling(adding: outcome.app)
            saveItems()
            if let request = item.zeusRequest {
                ZeusGroup.writeResult(Self.result(of: outcome, for: request))
            }
        } catch {
            fail(item, because: error.localizedDescription)
            if let request = item.zeusRequest {
                ZeusGroup.writeResult(ZeusRequestResult(
                    id: request.id,
                    outcome: .failed,
                    failure: Self.failure(for: error),
                    message: error.localizedDescription
                ))
            }
        }
        if isAccessing {
            file.stopAccessingSecurityScopedResource()
        }
        // Only once the app no longer counts as on its way in, so the next
        // launch can't find it written down without its IPA.
        removeCopy(of: item, at: file)
    }

    /// What an install does when the app is installed already. An app from
    /// Zeus must be the one its request names, and replaces the copy
    /// installed after a one-tap question, or installs as new when there's
    /// none. Any other asks whether it replaces a copy or installs as new.
    private static func policy(for item: PendingInstall) -> AppInstallPolicy {
        guard let request = item.zeusRequest, let bundleIdentifier = request.bundleIdentifier else {
            return .ask
        }
        return .fromZeus(bundleIdentifier: bundleIdentifier, replacesFolder: request.replacesFolder)
    }

    /// What zContainer tells Zeus once an app it sent has installed, or the
    /// person kept the copy already there.
    private static func result(of outcome: AppInstallOutcome, for request: ZeusRequest) -> ZeusRequestResult {
        switch outcome {
        case .added(let app):
            ZeusRequestResult(id: request.id, outcome: .added, app: app)
        case .replaced(let app):
            ZeusRequestResult(id: request.id, outcome: .replaced, app: app)
        case .cancelled:
            ZeusRequestResult(id: request.id, outcome: .cancelled)
        }
    }

    /// Why an app from Zeus failed, as Zeus reads it: the copy to replace
    /// was open, or the IPA held another app than the request named. Any
    /// other failure only has its message.
    private static func failure(for error: any Error) -> ZeusRequestFailure? {
        switch error as? AppInstallError {
        case .running:
            .running
        case .bundleMismatch:
            .mismatch
        case .invalidBundleIdentifier, nil:
            nil
        }
    }

    /// Deletes zContainer's own copy of an app's IPA once it's done with: a
    /// download's whole folder, the copy Files made, or the copy of an app
    /// from Zeus with its folder.
    private func removeCopy(of item: PendingInstall, at file: URL) {
        switch item.source {
        case .link, .pickedFile, .zeusRequest:
            try? FileManager.default.removeItem(at: file)
            PendingInstallStore.removeFolder(for: item.id)
        case .openedFile:
            break
        }
    }

    /// Marks an app as failed, and says so in an alert when no list shows it.
    private func fail(_ item: PendingInstall, because reason: String) {
        item.fail(reason)
        saveItems()
        if reportsFailures {
            coordinator.errorMessage = "zc.onboarding.apps.failedAlert %@ %@".localizeWithFormat(item.name, reason)
        }
    }

    /// Writes down the apps still on their way in.
    private func saveItems() {
        PendingInstallStore.save(items)
    }
}
