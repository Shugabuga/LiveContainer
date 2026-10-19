//
//  PendingInstallQueue.swift
//  LiveContainerSwiftUI
//

import Combine
import Foundation

/// The apps sent to zContainer while onboarding shows, so none is lost.
///
/// An install link starts downloading the moment it arrives, whatever step
/// is showing: a one-time `http://127.0.0.1` link from Zeus only answers for
/// about a minute. Installing waits until onboarding reaches Add Apps,
/// since the steps before it set up and check the certificate the apps are
/// signed with, and the Check Setup step signs a test library that an
/// install's signing shouldn't run beside. Apps then install one at a time,
/// as every install does, each through AppLaunchCoordinator.
///
/// Apps still on their way in when onboarding closes go on in the same way,
/// and links that arrive meanwhile join them rather than being turned away
/// by the install running.
@MainActor
@Observable
final class PendingInstallQueue {
    /// The apps, in the order they arrived.
    private(set) var items: [PendingInstall] = []
    /// Whether installs wait, as they do until onboarding reaches Add Apps.
    /// Downloads never wait.
    private(set) var holdsInstalls = false

    /// Whether a failure shows as an alert, as it does while no list shows
    /// it: once onboarding has closed.
    @ObservationIgnored private var reportsFailures = true
    /// Whether one of the apps is installing.
    @ObservationIgnored private var isInstalling = false
    @ObservationIgnored private let coordinator: AppLaunchCoordinator

    init(coordinator: AppLaunchCoordinator) {
        self.coordinator = coordinator
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
            add(PendingInstall(source: .openedFile(url)))
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

    /// Takes an IPA picked in Files, which Files copied for zContainer.
    func add(pickedFile url: URL) {
        add(PendingInstall(source: .pickedFile(url)))
    }

    private func add(_ item: PendingInstall) {
        items.append(item)
        installNext()
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

    /// Downloads a link's IPA into a folder of its own, the way installing
    /// from a link always does, with the progress on the app's row.
    private func download(_ item: PendingInstall, from url: URL) async {
        let folder = Self.folder(for: item)
        let destination = folder.appending(path: PendingInstallSource.downloadName(for: url))
        let downloader = DownloadHelper()
        // DownloadHelper reports its progress on the main queue.
        let progress = downloader.$downloadProgress.sink { [weak item] fraction in
            MainActor.assumeIsolated {
                item?.downloadProgressed(Double(fraction))
            }
        }
        defer { progress.cancel() }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try await downloader.download(url: url, to: destination)
            item.downloaded(to: destination)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            fail(item, because: "zc.onboarding.apps.downloadFailed %@".localizeWithFormat(error.localizedDescription))
        }
        installNext()
    }

    /// Where a link's IPA downloads to: a folder of its own, since several
    /// can download at once.
    private static func folder(for item: PendingInstall) -> URL {
        URL.temporaryDirectory.appending(path: "ReceivedApps/\(item.id.uuidString)", directoryHint: .isDirectory)
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

    private func install(_ item: PendingInstall) async {
        guard let file = item.file else {
            item.finishInstalling(adding: nil)
            return
        }
        await waitForOtherInstalls()
        item.startInstalling()
        do {
            let app = try await coordinator.installReceivedIPA(at: file, isOwnCopy: item.source.isOwnCopy)
            item.finishInstalling(adding: app)
        } catch {
            fail(item, because: error.localizedDescription)
        }
        removeCopy(of: item, at: file)
    }

    /// Waits while AppLaunchCoordinator installs something else, as it may
    /// once onboarding has closed, since it installs one app at a time.
    private func waitForOtherInstalls() async {
        while coordinator.isInstalling {
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = coordinator.isInstalling
                } onChange: {
                    continuation.resume()
                }
            }
        }
    }

    /// Deletes zContainer's own copy of an app's IPA once it's done with: a
    /// download's whole folder, or the copy Files made.
    private func removeCopy(of item: PendingInstall, at file: URL) {
        switch item.source {
        case .link:
            try? FileManager.default.removeItem(at: Self.folder(for: item))
        case .pickedFile:
            try? FileManager.default.removeItem(at: file)
        case .openedFile:
            break
        }
    }

    /// Marks an app as failed, and says so in an alert when no list shows it.
    private func fail(_ item: PendingInstall, because reason: String) {
        item.fail(reason)
        if reportsFailures {
            coordinator.errorMessage = "zc.onboarding.apps.failedAlert %@ %@".localizeWithFormat(item.name, reason)
        }
    }
}
