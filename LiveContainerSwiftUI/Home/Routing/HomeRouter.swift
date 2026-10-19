//
//  HomeRouter.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Routes the URLs zContainer is opened with, and runs the checks the main
/// window makes when it opens, whatever screens that window shows. App links
/// go straight to the AppLaunchCoordinator, except install links that arrive
/// while onboarding shows, which wait in its queue; links meant for one
/// screen wait here until that screen takes them. What the checks find waits
/// here too, for the root view to show with `homeRouting(_:onRoute:)`.
@MainActor
@Observable
final class HomeRouter {
    /// Carries out the app links.
    @ObservationIgnored let coordinator: AppLaunchCoordinator
    /// The app state the launch checks read, the coordinator's own.
    @ObservationIgnored let sharedModel: SharedModel
    /// Holds install links while onboarding shows.
    @ObservationIgnored let onboarding: OnboardingModel

    /// A certificate link waiting for the certificate import to store it.
    private(set) var pendingCertificate: CertificateLink?

    /// A problem a launch check found, as the person reads it.
    var launchProblem: String?
    /// Why the last app launch failed, in full: the error it left, or a crash
    /// while signing.
    var crashReport = ""
    /// Whether `crashReport` is on screen.
    var isShowingCrashReport = false

    init(coordinator: AppLaunchCoordinator, onboarding: OnboardingModel) {
        self.coordinator = coordinator
        self.sharedModel = coordinator.sharedModel
        self.onboarding = onboarding
    }

    /// Sends a URL zContainer was opened with where it goes, and returns that
    /// route, or nil when zContainer doesn't handle the URL.
    @discardableResult
    func dispatchURL(_ url: URL) -> HomeRoute? {
        guard let route = HomeRoute(url: url) else {
            return nil
        }
        switch route {
        case .home:
            break
        case .app(let link):
            send(link)
        case .certificate(let link):
            pendingCertificate = link
        }
        return route
    }

    /// Hands an app link to the coordinator. An install link that arrives
    /// while onboarding shows, or while apps it received are still coming in,
    /// waits in onboarding's queue instead, downloading at once, since a
    /// one-time link from Zeus only answers for about a minute.
    private func send(_ link: AppLink) {
        if case .install(let address) = link, onboarding.takeInstallLink(address) {
            return
        }
        coordinator.handle(link)
    }

    /// Hands the waiting certificate link to the import that stores it, once.
    func takePendingCertificate() -> CertificateLink? {
        defer { pendingCertificate = nil }
        return pendingCertificate
    }

    /// Runs when the main window opens: closes it when zContainer's main window
    /// is already open in another one, runs the launch checks, and opens the
    /// web page an app asked zContainer to show on its next launch.
    ///
    /// On iPad, a window that closes again, or the main window running this a
    /// second time, skips the checks, so what they found doesn't show twice.
    /// An iPhone runs them every time, as it always has.
    func start(in scene: UIWindowScene?) async {
        guard acceptMainWindow(scene) || SharedModel.isPhone else {
            return
        }
        checkLastLaunchError()
        checkTeamId()
        checkAndSaveBundleId()
        checkGetTaskAllow()
        checkPrivateContainerBookmark()
        openWebPageForThisLaunch()
        await checkZeusCertificate()
    }

    /// Notes that a window closed. When it was the main window, the next one
    /// to open becomes the main window.
    func sceneDidDisconnect(_ scene: UIScene) {
        guard let mainScene = MainWindow.scene, mainScene === scene else {
            return
        }
        MainWindow.scene = nil
        sharedModel.mainWindowOpened = false
    }

    /// Records this window as the main window and returns true. When the main
    /// window is already open, it asks iOS to close this one instead and
    /// returns false.
    ///
    /// On iPad it also returns false for the main window itself, so running
    /// again there leaves it open. An iPhone keeps the old path, where a
    /// second run asks to close its only window, as it always has.
    private func acceptMainWindow(_ scene: UIWindowScene?) -> Bool {
        defer {
            sharedModel.mainWindowOpened = true
        }
        if !SharedModel.isPhone, let scene, let mainScene = MainWindow.scene, mainScene === scene {
            return false
        }
        if let session = scene?.session, sharedModel.mainWindowOpened {
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { error in
                print(error)
            }
            return false
        }
        MainWindow.scene = scene
        return true
    }

    /// Opens the page an app asked zContainer to show, through
    /// `LCSharedUtils.setWebPageUrlForNextLaunch`, in the built-in browser.
    private func openWebPageForThisLaunch() {
        guard let webPage = UserDefaults.standard.string(forKey: "webPageToOpen") else {
            return
        }
        UserDefaults.standard.removeObject(forKey: "webPageToOpen")
        Task { await coordinator.openWebView(urlString: webPage) }
    }
}
