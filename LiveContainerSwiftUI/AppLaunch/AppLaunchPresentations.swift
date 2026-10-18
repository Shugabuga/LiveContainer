//
//  AppLaunchPresentations.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Shows what AppLaunchCoordinator's flows ask for, wherever they start:
/// errors, which app an install replaces, whether to stop the multitasking
/// apps, the JIT wait, download progress and the built-in browser. The root
/// view applies it once, through `appLaunchPresentations(_:)`.
struct AppLaunchPresentations: ViewModifier {
    let coordinator: AppLaunchCoordinator

    func body(content: Content) -> some View {
        @Bindable var coordinator = coordinator
        @Bindable var installReplacePrompt = coordinator.installReplacePrompt
        @Bindable var runWhenMultitaskPrompt = coordinator.runWhenMultitaskPrompt
        @Bindable var jitPrompt = coordinator.jitPrompt

        content
            .downloadAlert(helper: coordinator.downloadHelper)
            .alert("lc.common.error".loc, item: $coordinator.errorMessage) { message in
                Button("lc.common.ok".loc) { }
                Button("lc.common.copy".loc) {
                    UIPasteboard.general.string = message
                }
            } message: { message in
                Text(message)
            }
            .alert("lc.appList.installation".loc, isPresented: $installReplacePrompt.isPresented) {
                ForEach(coordinator.installOptions) { option in
                    Button(option.isReplace ? option.nameOfFolderToInstall : "lc.appList.installAsNew".loc,
                           role: option.isReplace ? .destructive : nil) {
                        installReplacePrompt.answer(option)
                    }
                }
                Button("lc.appList.abortInstallation".loc, role: .cancel) {
                    installReplacePrompt.answer(nil)
                }
            } message: {
                Text("lc.appList.installReplaceTip".loc)
            }
            .alert("lc.webView.runApp".loc, isPresented: $runWhenMultitaskPrompt.isPresented) {
                Button("lc.common.continue".loc, role: .destructive) {
                    runWhenMultitaskPrompt.answer(true)
                }
                Button("lc.common.cancel".loc, role: .cancel) {
                    runWhenMultitaskPrompt.answer(false)
                }
            } message: {
                Text("lc.appBanner.confirmRunWhenMultitasking".loc)
            }
            .sheet(isPresented: $jitPrompt.isPresented, onDismiss: { jitPrompt.answer(false) }) {
                JITWaitView(log: coordinator.jitLog, prompt: jitPrompt)
            }
            .fullScreenCover(isPresented: $coordinator.isShowingWebPage) {
                if let webPageURL = coordinator.webPageURL {
                    LCWebView(url: .constant(webPageURL), isPresent: $coordinator.isShowingWebPage) { address in
                        await coordinator.installFromPlist(urlStr: address)
                    }
                }
            }
    }
}

extension View {
    /// Shows what the coordinator's install and launch flows ask for. Apply it
    /// once, to the root view of the main window.
    func appLaunchPresentations(_ coordinator: AppLaunchCoordinator) -> some View {
        modifier(AppLaunchPresentations(coordinator: coordinator))
    }
}
