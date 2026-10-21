//
//  HomeRouter.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Routes the URLs zContainer is opened with, and runs the checks the main
/// window makes when it opens, whatever screens that window shows. App links
/// go straight to the AppLaunchCoordinator, except install links that arrive
/// while onboarding shows, while apps it received are still coming in, or
/// while another app installs, which wait in onboarding's queue. What the
/// checks find waits here, for the root view to show with
/// `homeRouting(_:onRoute:)`, as do the questions a certificate sent to
/// zContainer asks.
///
/// It also keeps zContainer's side of the app group it shares with Zeus up to
/// date: it takes the requests Zeus leaves there, from a link or when the
/// window comes to the front, and writes the list of apps Zeus reads when
/// the window opens, after every install or removal, and as zContainer stops
/// being the active app and again in the background.
@MainActor
@Observable
final class HomeRouter {
    /// Carries out the app links.
    @ObservationIgnored let coordinator: AppLaunchCoordinator
    /// The app state the launch checks read, the coordinator's own.
    @ObservationIgnored let sharedModel: SharedModel
    /// Holds install links while onboarding shows, while apps it received are
    /// still coming in, or while another app installs, and the apps Zeus sends.
    @ObservationIgnored let onboarding: OnboardingModel

    /// A .p12 file zContainer was asked to open, while its password is
    /// asked for.
    var lockedCertificate: LockedCertificate?
    /// A certificate sent to zContainer, while the person is asked whether
    /// to use it.
    var certificateOffer: CertificateOffer?
    /// The team of the certificate just stored from a link, a file or Zeus,
    /// while zContainer says it's ready.
    var storedCertificateTeam: String?
    /// Goes up by one whenever a certificate sent to zContainer is stored,
    /// so onboarding reads the certificate again.
    var certificatesStored = 0

    /// A problem a launch check found, or a certificate or a request from
    /// Zeus ran into, as the person reads it.
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
        coordinator.onAppsChanged = { [sharedModel] in
            ZeusGroup.writeManifest(from: sharedModel)
        }
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
            Task { await review(link) }
        case .certificateFile(let url):
            openCertificateFile(url)
        case .zeusRequests(let ids):
            Task { await takeZeusRequests(ids) }
        }
        return route
    }

    /// Hands an app link to the coordinator. An install link that arrives
    /// while onboarding shows, while apps it received are still coming in, or
    /// while another app installs, waits in onboarding's queue instead,
    /// downloading at once, since a one-time link from Zeus only answers for
    /// about a minute.
    private func send(_ link: AppLink) {
        if onboarding.takeLink(link, whileInstalling: coordinator.isInstalling) {
            return
        }
        coordinator.handle(link)
    }

    /// Runs when the main window opens: closes it when zContainer's main window
    /// is already open in another one, runs the launch checks, and opens the
    /// web page an app asked zContainer to show on its next launch. Then it
    /// clears out old answers to Zeus, takes the requests Zeus left while no
    /// link reached zContainer, and writes the list of apps for Zeus.
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
        ZeusGroup.sweepResults()
        await rescanZeusRequests()
        ZeusGroup.writeManifest(from: sharedModel)
    }

    /// Runs when the main window comes to the front: takes the requests Zeus
    /// left while a guest app had the link that named them.
    func sceneBecameActive() async {
        await rescanZeusRequests()
    }

    /// Runs as the main window stops being the active one, as when the person
    /// starts switching to Zeus, and again when it goes to the background:
    /// writes the list of apps, so Zeus reads what zContainer holds now.
    func sceneEnteredBackground() {
        ZeusGroup.writeManifest(from: sharedModel)
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
