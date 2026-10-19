//
//  HomeScreenModel+Opening.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Opening things from the Home Screen: apps, which zoom open from their icon
/// before zContainer turns into them, Settings and an app's settings, which
/// open over the Home Screen, and the actions in an app's long-press menu.
extension HomeScreenModel {
    /// Opens what an icon stands for, unless edit mode is on or search covers
    /// the icons: Settings, or the app, after Face ID when the app is locked.
    func open(_ item: HomeItem) {
        guard !isEditing, !isSearching, drag == nil else {
            return
        }
        switch item {
        case .settings:
            present(.settings)
        case .app(let key):
            guard let app = apps[key] else {
                return
            }
            launch(app, from: item)
        }
    }

    /// Launches an app through the coordinator. Just before zContainer turns
    /// into the app, the app zooms open from its icon, or from the middle of
    /// the screen when its icon isn't showing. The page showing is saved
    /// then, as zContainer quits on the way into the app and comes back to it.
    func launch(_ app: LCAppModel, from item: HomeItem? = nil) {
        let zoomItem = item ?? app.homeKey.map(HomeItem.app) ?? .settings
        let frame = item.flatMap(iconFrame(of:)) ?? centeredIconFrame()
        let returnPage = page ?? 0
        Task {
            await coordinator.open(app) {
                HomeLayoutStorage.saveReturnPage(returnPage)
                await self.playLaunchZoom(HomeLaunchZoom(item: zoomItem, iconFrame: frame))
            }
        }
    }

    /// Plays the launch zoom and returns when it has filled the screen. The
    /// zoom view calls `launchZoomDidFinish()` at the end of its animation.
    private func playLaunchZoom(_ zoom: HomeLaunchZoom) async {
        await withCheckedContinuation { continuation in
            launchZoomContinuation?.resume()
            launchZoomContinuation = continuation
            launchZoom = zoom
        }
        // zContainer quits as the app opens. If it's still here after a few
        // seconds, the launch didn't happen, so the Home Screen comes back.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.launchZoom?.id == zoom.id {
                self?.launchZoom = nil
            }
        }
    }

    /// Lets the launch go ahead once the zoom has filled the screen.
    func launchZoomDidFinish() {
        launchZoomContinuation?.resume()
        launchZoomContinuation = nil
    }

    /// An icon's frame on screen, when it shows on the page in view or in the dock.
    func iconFrame(of item: HomeItem) -> CGRect? {
        guard let metrics else {
            return nil
        }
        switch layout.slot(of: item) {
        case .page(let page, let index)?:
            guard page == (self.page ?? 0) else {
                return nil
            }
            return metrics.iconFrame(around: metrics.iconCenter(at: index))
        case .dock(let index)?:
            return metrics.iconFrame(around: metrics.dockIconCenter(at: index, count: layout.dock.count))
        case nil:
            return nil
        }
    }

    private func centeredIconFrame() -> CGRect {
        guard let metrics else {
            return .zero
        }
        return metrics.iconFrame(around: CGPoint(x: metrics.size.width / 2, y: metrics.size.height / 2))
    }

    // MARK: Screens over the Home Screen

    /// Opens a screen over the Home Screen. From iOS 18 it zooms out of its
    /// icon and covers the screen, so the status bar follows it from then on.
    func present(_ screen: HomePresentedScreen) {
        if #available(iOS 18.0, *) {
            isCoveredByScreen = true
        }
        presentedScreen = screen
    }

    /// Hands the status bar back to the Home Screen once the screen over it
    /// has closed.
    func presentedScreenDidClose() {
        isCoveredByScreen = false
    }

    /// Opens an app's settings, zooming out of its icon.
    func showSettings(for app: LCAppModel) {
        present(.appSettings(app))
    }

    /// Closes an app's settings, as the app asks before it hides itself.
    func closeAppSettings() {
        if case .appSettings = presentedScreen {
            presentedScreen = nil
        }
    }

    // MARK: Long-press actions

    /// Makes a new container for an app and opens the app in it. Search
    /// closes first when the app was found there, so its zoom shows.
    func openInNewContainer(_ app: LCAppModel) {
        do {
            try app.makeNewContainer(sharedModel: sharedModel)
        } catch {
            coordinator.errorMessage = error.localizedDescription
            return
        }
        if isSearching {
            closeSearch()
        }
        launch(app, from: app.homeKey.map(HomeItem.app))
    }

    /// Locks an app behind Face ID, Touch ID or the passcode, after asking for
    /// it once, as iOS does. `hiding` also takes the app off the Home Screen;
    /// it then shows only in search's Hidden section.
    func requireAuthentication(for app: LCAppModel, hiding: Bool) {
        Task {
            do {
                guard try await LCUtils.authenticateUser() else {
                    return
                }
            } catch {
                coordinator.errorMessage = error.localizedDescription
                return
            }
            app.uiIsLocked = true
            await app.setLocked(newLockState: true)
            if hiding && !app.appInfo.isHidden {
                await app.toggleHidden()
            }
        }
    }

    /// Unlocks an app, after Face ID. A hidden app comes back to the Home Screen.
    func stopRequiringAuthentication(for app: LCAppModel) {
        Task {
            app.uiIsLocked = false
            await app.setLocked(newLockState: false)
        }
    }

    // MARK: Adding apps

    /// Opens Files to pick an IPA, from the add button in edit mode.
    func chooseIPA() {
        isChoosingIPA = true
    }

    /// Notes that Files closed.
    func filePickerDidClose() {
        isChoosingIPA = false
    }

    /// Installs the IPA picked in Files.
    func installPickedFiles(_ urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        Task {
            await coordinator.startInstallApp(url)
        }
    }

    /// Asks for a link to install an app from.
    func askForInstallURL() {
        installURL = ""
        isEnteringInstallURL = true
    }

    /// Installs from the link typed in.
    func installFromEnteredURL() {
        let address = installURL.trimmingCharacters(in: .whitespacesAndNewlines)
        installURL = ""
        guard !address.isEmpty else {
            return
        }
        Task {
            await coordinator.install(fromAddress: address)
        }
    }
}
