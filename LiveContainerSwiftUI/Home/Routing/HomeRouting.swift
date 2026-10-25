//
//  HomeRouting.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Connects the main window's root view to the HomeRouter: runs the launch
/// checks when the window opens, routes the URLs zContainer is opened with,
/// tells the router when the window comes to the front, stops being the active
/// one or goes to the background, notices when the window closes, and shows
/// what the router and the AppLaunchCoordinator ask for, including a
/// certificate sent to zContainer. `onRoute` hears each route after the
/// router sent it on, so the root view can bring up the screen it concerns.
/// It also hears the requests from Zeus that the window finds as it comes
/// to the front, just before the router takes them.
struct HomeRouting: ViewModifier {
    let router: HomeRouter
    let onRoute: @MainActor (HomeRoute) -> Void

    @EnvironmentObject private var sceneDelegate: SceneDelegate
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        @Bindable var router = router

        content
            .appLaunchPresentations(router.coordinator)
            .alert("lc.common.error".loc, item: $router.launchProblem) { problem in
                Button("lc.common.ok".loc) { }
                Button("lc.common.copy".loc) {
                    UIPasteboard.general.string = problem
                }
            } message: { problem in
                Text(problem)
            }
            .certificateImportPresentation(router)
            .sheet(isPresented: $router.isShowingCrashReport) {
                LaunchErrorReportView(report: router.crashReport)
            }
            .task {
                await router.start(in: sceneDelegate.window?.windowScene)
            }
            .onChange(of: scenePhase, scenePhaseChanged(from:to:))
            .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) { notification in
                if let scene = notification.object as? UIScene {
                    router.sceneDidDisconnect(scene)
                }
            }
            .onOpenURL { url in
                if let route = router.dispatchURL(url) {
                    onRoute(route)
                }
            }
    }

    /// Tells the router the window came to the front, stopped being the
    /// active one, as when the person starts switching to Zeus, or went to
    /// the background. The list of apps is written both of those times, so
    /// Zeus, which reads it as it becomes active, finds what zContainer holds
    /// now. Passing through inactive on the way back changes nothing. When
    /// coming to the front takes requests Zeus left, `onRoute` hears them
    /// before they're taken, as it hears a link from Zeus.
    private func scenePhaseChanged(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            Task {
                await router.sceneBecameActive(onRoute: onRoute)
            }
        case .inactive where oldPhase == .active, .background:
            router.sceneEnteredBackground()
        default:
            break
        }
    }
}

extension View {
    /// Makes this view the main window's root for the router. Apply it once.
    func homeRouting(_ router: HomeRouter, onRoute: @escaping @MainActor (HomeRoute) -> Void = { _ in }) -> some View {
        modifier(HomeRouting(router: router, onRoute: onRoute))
    }
}
