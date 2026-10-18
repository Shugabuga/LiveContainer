//
//  HomeRouting.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Connects the main window's root view to the HomeRouter: runs the launch
/// checks when the window opens, routes the URLs zContainer is opened with,
/// notices when the window closes, and shows what the router and the
/// AppLaunchCoordinator ask for. `onRoute` hears each route after the router
/// sent it on, so the root view can bring up the screen it concerns.
struct HomeRouting: ViewModifier {
    let router: HomeRouter
    let onRoute: @MainActor (HomeRoute) -> Void

    @EnvironmentObject private var sceneDelegate: SceneDelegate

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
            .sheet(isPresented: $router.isShowingCrashReport) {
                LaunchErrorReportView(report: router.crashReport)
            }
            .task {
                await router.start(in: sceneDelegate.window?.windowScene)
            }
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
}

extension View {
    /// Makes this view the main window's root for the router. Apply it once.
    func homeRouting(_ router: HomeRouter, onRoute: @escaping @MainActor (HomeRoute) -> Void = { _ in }) -> some View {
        modifier(HomeRouting(router: router, onRoute: onRoute))
    }
}
