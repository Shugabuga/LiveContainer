//
//  AppShortcutMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Add to Home Screen, in the toolbar of an app's settings: ways to open the
/// app inside zContainer from the iPhone's own Home Screen, as LiveContainer's
/// app menu had them. Copy Launch URL copies the link a Shortcuts shortcut
/// can open, Save App Icon saves the icon for that shortcut to Files, and
/// Create App Clip adds a web clip through a configuration profile. On iOS 18
/// and later, the icon's style is asked for first.
struct AppShortcutMenu: View {
    @ObservedObject var app: LCAppModel

    /// What waits for the icon style to be chosen.
    @State private var pendingKind: AppShortcutKind?
    /// The icon being saved to Files.
    @State private var iconFile: AppIconFile?
    @State private var isSavingIcon = false
    /// The web clip profile Safari is offering to download.
    @State private var webClipLink: URL?
    @State private var isShowingWebClip = false
    /// Goes up by one after the launch link is copied, for the haptic.
    @State private var copyCount = 0
    @State private var errorMessage: String?

    var body: some View {
        Menu("lc.appBanner.addToHomeScreen".loc, systemImage: "plus.app") {
            Button("lc.appBanner.copyLaunchUrl".loc, systemImage: "link", action: copyLaunchLink)
            Button("lc.appBanner.saveAppIcon".loc, systemImage: "square.and.arrow.down", action: saveIcon)
            Button("lc.appBanner.createAppClip".loc, systemImage: "appclip", action: createWebClip)
        }
        .confirmationDialog(
            "lc.appList.generatedIconStyleSelector.title".loc,
            item: $pendingKind,
            titleVisibility: .visible
        ) { kind in
            Button("lc.appList.generatedIconStyleSelector.light".loc) {
                make(kind, style: .Light)
            }
            Button("lc.appList.generatedIconStyleSelector.dark".loc) {
                make(kind, style: .Dark)
            }
            Button("lc.appList.generatedIconStyleSelector.original".loc) {
                make(kind, style: .Original)
            }
        }
        .fileExporter(
            isPresented: $isSavingIcon,
            item: iconFile,
            contentTypes: [.png],
            defaultFilename: AppShortcuts.iconFileName(for: app),
            onCompletion: iconSaved
        )
        .sheet(isPresented: $isShowingWebClip) {
            if let webClipLink {
                SafariView(url: .constant(webClipLink))
            }
        }
        .alert("lc.common.error".loc, item: $errorMessage) { _ in
            Button("lc.common.ok".loc) { }
        } message: { message in
            Text(message)
        }
        .sensoryFeedback(.success, trigger: copyCount)
    }

    private func copyLaunchLink() {
        guard let link = AppShortcuts.launchLink(for: app) else {
            return
        }
        UIPasteboard.general.string = link
        copyCount += 1
    }

    private func saveIcon() {
        chooseStyle(for: .iconFile)
    }

    private func createWebClip() {
        chooseStyle(for: .webClip)
    }

    /// Asks for the icon's style on iOS 18 and later, which draw dark icons.
    /// Earlier versions draw the light one.
    private func chooseStyle(for kind: AppShortcutKind) {
        if #available(iOS 18.0, *) {
            pendingKind = kind
        } else {
            make(kind, style: .Light)
        }
    }

    private func make(_ kind: AppShortcutKind, style: GeneratedIconStyle) {
        do {
            switch kind {
            case .iconFile:
                iconFile = try AppShortcuts.iconFile(for: app, style: style)
                isSavingIcon = true
            case .webClip:
                webClipLink = try AppShortcuts.webClipLink(for: app, style: style)
                isShowingWebClip = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func iconSaved(_ result: Result<URL, Error>) {
        iconFile = nil
        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
        }
    }
}
