//
//  HomeRouter.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Routes the URLs zContainer is opened with, and runs the checks the main
/// window makes when it opens, whatever screens that window shows. App links
/// go straight to the AppLaunchCoordinator; links meant for one screen wait
/// here until that screen takes them. What the checks find waits here too,
/// for the root view to show with `homeRouting(_:onRoute:)`.
@MainActor
@Observable
final class HomeRouter {
    /// Carries out the app links.
    @ObservationIgnored let coordinator: AppLaunchCoordinator
    /// The app state the launch checks read, the coordinator's own.
    @ObservationIgnored let sharedModel: SharedModel

    /// An app source link waiting for the Sources screen to add it.
    private(set) var pendingSourceURL: String?
    /// A certificate link waiting for the certificate import to store it.
    private(set) var pendingCertificate: CertificateLink?

    /// A problem a launch check found, as the person reads it.
    var launchProblem: String?
    /// Why the last app launch failed, in full: the error it left, or a crash
    /// while signing.
    var crashReport = ""
    /// Whether `crashReport` is on screen.
    var isShowingCrashReport = false

    /// The window showing zContainer's main screen. A second window that opens
    /// meanwhile closes, and only this one's closing frees the main screen.
    @ObservationIgnored private weak var mainWindowScene: UIWindowScene?

    init(coordinator: AppLaunchCoordinator) {
        self.coordinator = coordinator
        self.sharedModel = coordinator.sharedModel
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
            coordinator.handle(link)
        case .source(let sourceURL):
            pendingSourceURL = sourceURL
        case .certificate(let link):
            pendingCertificate = link
        }
        return route
    }

    /// Hands the waiting app source link to the screen that adds it, once.
    func takePendingSource() -> String? {
        defer { pendingSourceURL = nil }
        return pendingSourceURL
    }

    /// Hands the waiting certificate link to the import that stores it, once.
    func takePendingCertificate() -> CertificateLink? {
        defer { pendingCertificate = nil }
        return pendingCertificate
    }

    /// Runs when the main window opens: closes it when zContainer's main window
    /// is already open in another one, runs the launch checks, and opens the
    /// web page an app asked zContainer to show on its next launch.
    func start(in scene: UIWindowScene?) async {
        closeDuplicatedWindow(scene)
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
        guard let mainWindowScene, mainWindowScene === scene else {
            return
        }
        self.mainWindowScene = nil
        sharedModel.mainWindowOpened = false
    }

    /// Asks iOS to close this window when the main window is already open in
    /// another, and otherwise records this one as the main window.
    private func closeDuplicatedWindow(_ scene: UIWindowScene?) {
        if let session = scene?.session, sharedModel.mainWindowOpened {
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { error in
                print(error)
            }
        } else {
            mainWindowScene = scene
        }
        sharedModel.mainWindowOpened = true
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
