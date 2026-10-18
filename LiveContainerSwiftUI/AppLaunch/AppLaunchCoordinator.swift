//
//  AppLaunchCoordinator.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Installs, launches, hides and removes the apps inside zContainer, whichever
/// screen asks. It is the delegate of every LCAppModel, so JIT launches and the
/// question about stopping multitasking apps work from any screen. It keeps
/// what its flows need to show (errors, questions, the JIT log, install
/// progress and the built-in browser), and the root view presents them with
/// `appLaunchPresentations(_:)`.
@MainActor
@Observable
final class AppLaunchCoordinator {
    /// The installed apps and the hidden-app state the flows work on.
    @ObservationIgnored let sharedModel: SharedModel

    /// Downloads the IPAs that install links point at. `downloadAlert(helper:)`
    /// shows its progress.
    @ObservationIgnored let downloadHelper = DownloadHelper()

    /// The error to show, as the person reads it, or nil when there is none.
    var errorMessage: String?

    /// Whether an IPA is being installed: downloaded, unpacked, moved in and
    /// signed. Install requests that arrive meanwhile are ignored.
    var isInstalling = false
    /// How far unpacking and signing the current IPA has come, from 0 to 1.
    var installProgress: Float = 0
    @ObservationIgnored private var installObserver: NSKeyValueObservation?

    /// The choices `installReplacePrompt` offers while it is open.
    private(set) var installOptions: [AppReplaceOption] = []
    /// Asks whether a new app replaces an installed app with its bundle ID.
    let installReplacePrompt = AppLaunchPrompt<AppReplaceOption>()
    /// Asks whether to stop the multitasking apps to run an app the classic way.
    let runWhenMultitaskPrompt = AppLaunchPrompt<Bool>()
    /// Waits while a JIT enabler attaches to an app, and asks whether to launch it.
    let jitPrompt = AppLaunchPrompt<Bool>()
    /// What the JIT enabler has reported so far.
    private(set) var jitLog = ""

    /// The page the built-in browser shows.
    private(set) var webPageURL: URL?
    /// Whether the built-in browser is on screen.
    var isShowingWebPage = false

    /// Goes up by one each time an app asks to close the screen that shows its
    /// settings, which it does before it hides itself. Screens that show an
    /// app's settings close them when this changes.
    private(set) var appSettingsCloseRequests = 0

    /// Makes the coordinator the delegate of every app already loaded.
    init(sharedModel: SharedModel) {
        self.sharedModel = sharedModel
        for app in sharedModel.apps + sharedModel.hiddenApps {
            app.delegate = self
        }
    }

    /// Carries out an app link, as HomeRouter hands them over.
    func handle(_ link: AppLink) {
        switch link {
        case .install(let address):
            Task { await installFromUrl(urlStr: address) }
        case let .launch(bundleName, containerFolderName, url, forceJIT):
            Task { await launchAppWithBundleId(bundleId: bundleName, container: containerFolderName, urlStr: url, forceJIT: forceJIT) }
        case .openURL(let target):
            Task { await openWebView(urlString: target) }
        }
    }

    // MARK: Installing

    /// Installs from a link the person typed: an `itms-services://` link
    /// through its manifest, anything else as the IPA's own address.
    func install(fromAddress address: String) async {
        if let url = URL(string: address), url.scheme?.lowercased() == "itms-services" {
            await installFromPlist(urlStr: address)
        } else {
            await installFromUrl(urlStr: address)
        }
    }

    /// Installs an IPA the person picked in Files, then deletes the copy the
    /// file importer made of it.
    func startInstallApp(_ fileUrl: URL) async {
        isInstalling = true
        defer { isInstalling = false }
        do {
            try await installIpaFile(fileUrl)
            try FileManager.default.removeItem(at: fileUrl)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Installs the app an `itms-services://` link or a manifest URL points at:
    /// reads the manifest, then installs its software package.
    func installFromPlist(urlStr: String) async {
        if isInstalling {
            return
        }
        if sharedModel.multiLCStatus == 2 {
            errorMessage = "lc.appList.manageInPrimaryTip".loc
            return
        }

        var plistUrlStr = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if plistUrlStr.lowercased().hasPrefix("itms-services://") {
            guard let manifestURL = URLComponents(string: plistUrlStr)?.queryItems?.first(where: { $0.name == "url" })?.value else {
                errorMessage = "lc.appList.plistInvalidError".loc
                return
            }
            plistUrlStr = manifestURL
        }

        guard let plistUrl = URL(string: plistUrlStr) else {
            errorMessage = "lc.appList.urlInvalidError".loc
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: plistUrl)
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let items = plist["items"] as? [[String: Any]],
                  let assets = items.first?["assets"] as? [[String: Any]] else {
                errorMessage = "lc.appList.plistParseError".loc
                return
            }
            let ipaUrlStr = assets.lazy.compactMap { asset -> String? in
                guard asset["kind"] as? String == "software-package" else {
                    return nil
                }
                return asset["url"] as? String
            }.first
            guard let ipaUrlStr else {
                errorMessage = "lc.appList.plistNoIpaError".loc
                return
            }
            await installFromUrl(urlStr: ipaUrlStr)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Installs the IPA at a web address, downloading it first, or at a file
    /// URL, such as an IPA opened with zContainer or shared to it.
    func installFromUrl(urlStr: String) async {
        if isInstalling {
            return
        }
        if sharedModel.multiLCStatus == 2 {
            errorMessage = "lc.appList.manageInPrimaryTip".loc
            return
        }
        guard let installUrl = URL(string: urlStr) else {
            errorMessage = "lc.appList.urlInvalidError".loc
            return
        }

        isInstalling = true
        defer { isInstalling = false }

        if installUrl.isFileURL {
            await installLocalIpa(installUrl)
            return
        }

        do {
            let fileManager = FileManager.default
            let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(installUrl.lastPathComponent)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try await downloadHelper.download(url: installUrl, to: destinationURL)
            if downloadHelper.cancelled {
                return
            }
            try await installIpaFile(destinationURL)
            try fileManager.removeItem(at: destinationURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Installs an IPA from a file URL. When zContainer can't read the file
    /// itself, it tries the bookmark the share extension leaves and then
    /// security-scoped access. An IPA in the Inbox is deleted afterwards.
    private func installLocalIpa(_ fileURL: URL) async {
        var installUrl = fileURL
        let fileExtension = installUrl.pathExtension.lowercased()
        if fileExtension != "ipa" && fileExtension != "tipa" {
            errorMessage = "lc.appList.urlFileIsNotIpaError".loc
            return
        }

        let fm = FileManager.default
        var didStartAccessing = false
        if !fm.isReadableFile(atPath: installUrl.path),
           let bookmarkData = LCUtils.appGroupUserDefault.data(forKey: "LCLaunchExtensionFileBookmark") {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: URL.BookmarkResolutionOptions(rawValue: 1 << 10),
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                installUrl = resolvedURL
                didStartAccessing = resolvedURL.startAccessingSecurityScopedResource()
            } catch {
                errorMessage = "Failed to resolve shared IPA bookmark: \(error.localizedDescription)"
                return
            }
        }

        if !fm.isReadableFile(atPath: installUrl.path) && !didStartAccessing {
            didStartAccessing = installUrl.startAccessingSecurityScopedResource()
        }
        if !fm.isReadableFile(atPath: installUrl.path) && !didStartAccessing {
            errorMessage = "lc.appList.ipaAccessError".loc
            return
        }
        defer {
            if didStartAccessing {
                installUrl.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try await installIpaFile(installUrl)
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            let inboxURL = URL.documentsDirectory.appendingPathComponent("Inbox")
            if installUrl.deletingLastPathComponent().standardizedFileURL == inboxURL.standardizedFileURL {
                try fm.removeItem(at: installUrl)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Unpacks an IPA, moves its app into the Applications folder, patches and
    /// signs it, and adds it to the Home Screen. When an app with the same bundle
    /// ID is installed, it first asks whether the new app replaces it (after
    /// Face ID, when that app is hidden) and carries the replaced app's
    /// settings over. A signing problem doesn't stop the install: the app stays
    /// unsigned and the problem is shown.
    func installIpaFile(_ url: URL) async throws {
        let fm = FileManager()

        let overallProgress = Progress.discreteProgress(totalUnitCount: 100)
        installProgress = 0
        installObserver = overallProgress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let fraction = Float(progress.fractionCompleted)
            Task { @MainActor in
                self?.installProgress = fraction
            }
        }
        let decompressProgress = Progress.discreteProgress(totalUnitCount: 100)
        overallProgress.addChild(decompressProgress, withPendingUnitCount: 80)
        let payloadPath = fm.temporaryDirectory.appendingPathComponent("Payload")
        if fm.fileExists(atPath: payloadPath.path) {
            try fm.removeItem(at: payloadPath)
        }

        guard await Self.unpack(url.path, into: fm.temporaryDirectory.path, progress: decompressProgress) == 0 else {
            throw "lc.appList.urlFileIsNotIpaError".loc
        }

        let payloadContents = try fm.contentsOfDirectory(atPath: payloadPath.path)
        guard let appBundleName = payloadContents.first(where: { $0.hasSuffix(".app") }) else {
            throw "lc.appList.bundleNotFondError".loc
        }
        let appFolderPath = payloadPath.appendingPathComponent(appBundleName)
        guard let newAppInfo = LCAppInfo(bundlePath: appFolderPath.path),
              let bundleIdentifier = newAppInfo.bundleIdentifier() else {
            throw "lc.appList.infoPlistCannotReadError".loc
        }

        var appRelativePath = "\(bundleIdentifier.sanitizeNonACSII()).app"
        var outputFolder = LCPath.bundlePath.appendingPathComponent(appRelativePath)
        var appToReplace: LCAppModel?
        var sameBundleIdApps = sharedModel.apps.filter { $0.appInfo.bundleIdentifier() == bundleIdentifier }
        if sameBundleIdApps.isEmpty {
            sameBundleIdApps = sharedModel.hiddenApps.filter { $0.appInfo.bundleIdentifier() == bundleIdentifier }
            // Replacing a hidden app needs Face ID first.
            if !sameBundleIdApps.isEmpty && !sharedModel.isHiddenAppUnlocked {
                do {
                    guard try await LCUtils.authenticateUser() else {
                        return
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }
        }

        // The folder exists or the app is installed already: ask which copy
        // the new app replaces, if any.
        if fm.fileExists(atPath: outputFolder.path) || !sameBundleIdApps.isEmpty {
            appRelativePath = "\(bundleIdentifier)_\(Int(CFAbsoluteTimeGetCurrent())).app"
            installOptions = [AppReplaceOption(isReplace: false, nameOfFolderToInstall: appRelativePath)]
            for app in sameBundleIdApps {
                installOptions.append(AppReplaceOption(isReplace: true, nameOfFolderToInstall: app.appInfo.relativeBundlePath, appToReplace: app))
            }

            guard let installOptionChosen = await installReplacePrompt.ask() else {
                try fm.removeItem(at: payloadPath)
                return
            }

            if let replaced = installOptionChosen.appToReplace, replaced.uiIsShared {
                outputFolder = LCPath.lcGroupBundlePath.appendingPathComponent(installOptionChosen.nameOfFolderToInstall)
            } else {
                outputFolder = LCPath.bundlePath.appendingPathComponent(installOptionChosen.nameOfFolderToInstall)
            }
            appRelativePath = installOptionChosen.nameOfFolderToInstall
            appToReplace = installOptionChosen.appToReplace
            if installOptionChosen.isReplace {
                try fm.removeItem(at: outputFolder)
            }
        }

        try fm.moveItem(at: appFolderPath, to: outputFolder)
        guard let finalNewApp = LCAppInfo(bundlePath: outputFolder.path) else {
            errorMessage = "lc.appList.appInfoInitError".loc
            return
        }
        finalNewApp.relativeBundlePath = appRelativePath

        if appToReplace?.uiDontSign ?? false || LCUtils.appGroupUserDefault.bool(forKey: "LCDontSignApp") {
            finalNewApp.dontSign = true
        }
        let (signSuccess, signError) = await withCheckedContinuation { (continuation: CheckedContinuation<(Bool, String?), Never>) in
            finalNewApp.patchExecAndSignIfNeed(completionHandler: { success, error in
                continuation.resume(returning: (success, error))
            }, progressHandler: { signProgress in
                if let signProgress {
                    overallProgress.addChild(signProgress, withPendingUnitCount: 20)
                }
            }, forceSign: false)
        }
        // The app stays installed, unsigned, when signing failed.
        if let signError {
            errorMessage = signSuccess ? "\("lc.appList.signSuccessWithError".loc)\n\n\(signError)" : signError.loc
        }

        if let appToReplace {
            // Carry the replaced app's settings over.
            finalNewApp.autoSaveDisabled = true
            finalNewApp.isLocked = appToReplace.appInfo.isLocked
            finalNewApp.isHidden = appToReplace.appInfo.isHidden
            finalNewApp.isJITNeeded = appToReplace.appInfo.isJITNeeded
            finalNewApp.isShared = appToReplace.appInfo.isShared
            finalNewApp.spoofSDKVersion = appToReplace.appInfo.spoofSDKVersion
            finalNewApp.doSymlinkInbox = appToReplace.appInfo.doSymlinkInbox
            finalNewApp.containerInfo = appToReplace.appInfo.containerInfo
            finalNewApp.tweakFolder = appToReplace.appInfo.tweakFolder
            finalNewApp.selectedLanguage = appToReplace.appInfo.selectedLanguage
            finalNewApp.dataUUID = appToReplace.appInfo.dataUUID
            finalNewApp.orientationLock = appToReplace.appInfo.orientationLock
            finalNewApp.dontInjectTweakLoader = appToReplace.appInfo.dontInjectTweakLoader
            finalNewApp.hideLiveContainer = appToReplace.appInfo.hideLiveContainer
            finalNewApp.dontLoadTweakLoader = appToReplace.appInfo.dontLoadTweakLoader
            finalNewApp.doUseLCBundleId = appToReplace.appInfo.doUseLCBundleId
            finalNewApp.fixFilePickerNew = appToReplace.appInfo.fixFilePickerNew
            finalNewApp.fixLocalNotification = appToReplace.appInfo.fixLocalNotification
            finalNewApp.lastLaunched = appToReplace.appInfo.lastLaunched
            finalNewApp.jitLaunchScriptJs = appToReplace.appInfo.jitLaunchScriptJs
            finalNewApp.multitaskSpecified = appToReplace.appInfo.multitaskSpecified
            finalNewApp.classicMode = appToReplace.appInfo.classicMode
            finalNewApp.autoSaveDisabled = false
            finalNewApp.save()
        } else {
            // New apps spoof their SDK version by default.
            finalNewApp.spoofSDKVersion = true
        }
        finalNewApp.installationDate = Date.now

        let newAppModel = LCAppModel(appInfo: finalNewApp, delegate: self)
        if let appToReplace {
            if appToReplace.uiIsHidden {
                sharedModel.hiddenApps.removeAll { $0 == appToReplace }
                sharedModel.hiddenApps.append(newAppModel)
            } else {
                sharedModel.apps.removeAll { $0 == appToReplace }
                sharedModel.apps.append(newAppModel)
            }
        } else {
            sharedModel.apps.append(newAppModel)
            if let urlSchemes = finalNewApp.urlSchemes(), urlSchemes.count > 0 {
                UserDefaults.lcShared().mutableArrayValue(forKey: "LCGuestURLSchemes").addObjects(from: Array(urlSchemes))
            }
        }
    }

    /// Unpacks an IPA off the main actor. Returns 0 when it worked.
    @concurrent
    private nonisolated static func unpack(_ path: String, into destination: String, progress: Progress) async -> Int32 {
        extract(path, destination, progress)
    }

    // MARK: Removing

    /// Deletes an app's files and takes it off the Home Screen. With
    /// `deletingData`, its containers go too, with their keychain items;
    /// otherwise they stay, unused, for when the app comes back.
    func uninstall(_ app: LCAppModel, deletingData: Bool) async {
        let appInfo = app.appInfo
        let containers = appInfo.containers
        do {
            guard let bundlePath = appInfo.bundlePath() else {
                throw CocoaError(.fileNoSuchFile)
            }
            let fileManager = FileManager.default
            try fileManager.removeItem(atPath: bundlePath)
            removeApp(app: app)

            guard deletingData else {
                return
            }
            for container in containers {
                let folderName = container.folderName
                try fileManager.removeItem(at: LCPath.dataPath.appendingPathComponent(folderName))
                LCUtils.removeAppKeychain(dataUUID: folderName)
                sharedModel.appDataFolderNames.removeAll { $0 == folderName }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Takes an uninstalled app off the Home Screen, after its files are gone.
    func removeApp(app: LCAppModel) {
        sharedModel.apps.removeAll { $0 == app }
        sharedModel.hiddenApps.removeAll { $0 == app }
    }

    // MARK: Launching

    /// Opens an app tapped on the Home Screen. When the app already runs in a
    /// multitasking window, that window comes forward. Otherwise a locked app
    /// asks for Face ID first, and the app runs: signed if it needs to be, then
    /// in a multitasking window or with zContainer turning into it, as its
    /// settings say. `willLaunch` runs just before zContainer turns into the
    /// app, after signing, so the Home Screen can zoom into it.
    func open(_ app: LCAppModel, willLaunch: (@MainActor () async -> Void)? = nil) async {
        if #available(iOS 16.0, *),
           let folderName = app.uiSelectedContainer?.folderName,
           MultitaskManager.isUsing(container: folderName) {
            var found = false
            if #available(iOS 16.1, *) {
                found = MultitaskWindowManager.openExistingAppWindow(dataUUID: folderName)
            }
            if !found {
                found = MultitaskDockManager.shared.bringMultitaskViewToFront(uuid: folderName)
            }
            if found {
                return
            }
        }

        if app.appInfo.isLocked && !sharedModel.isHiddenAppUnlocked {
            do {
                guard try await LCUtils.authenticateUser() else {
                    return
                }
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        do {
            try await app.runApp(willLaunch: willLaunch)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Launches the app installed in the folder `bundleId`, as launch links and
    /// web clips ask. A locked or hidden app needs Face ID first, and hidden
    /// apps aren't found while Strict Hiding is on.
    func launchAppWithBundleId(bundleId: String, container: String?, urlStr: String? = nil, forceJIT: Bool? = nil) async {
        if bundleId.isEmpty {
            return
        }
        var appFound = sharedModel.apps.first { $0.appInfo.relativeBundlePath == bundleId }
        var isFoundAppLocked = appFound?.appInfo.isLocked ?? false
        if appFound == nil && !LCUtils.appGroupUserDefault.bool(forKey: "LCStrictHiding") {
            appFound = sharedModel.hiddenApps.first { $0.appInfo.relativeBundlePath == bundleId }
            isFoundAppLocked = appFound != nil
        }

        if isFoundAppLocked && !sharedModel.isHiddenAppUnlocked {
            do {
                guard try await LCUtils.authenticateUser() else {
                    return
                }
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        guard let appFound else {
            errorMessage = "lc.appList.appNotFoundError".loc
            return
        }

        do {
            try await appFound.runApp(multitask: nil, containerFolderName: container, urlStr: urlStr, forceJIT: forceJIT)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Opens a URL the way iOS would: an `itms-services` link installs its app,
    /// another app's URL scheme launches the installed app that declares it
    /// (after Face ID, when it is locked), and a web page opens in the built-in
    /// browser. A URL without a scheme is taken as https.
    func openWebView(urlString: String) async {
        guard var components = URLComponents(string: urlString), components.url != nil else {
            errorMessage = "lc.appList.urlInvalidError".loc
            return
        }
        if components.scheme?.isEmpty ?? true {
            components.scheme = "https"
        }
        guard let url = components.url, let scheme = components.scheme else {
            errorMessage = "lc.appList.urlInvalidError".loc
            return
        }

        if scheme.lowercased() == "itms-services" {
            await installFromPlist(urlStr: urlString)
            return
        }

        if scheme != "https" && scheme != "http" {
            var appListsToConsider = [sharedModel.apps]
            if sharedModel.isHiddenAppUnlocked || !LCUtils.appGroupUserDefault.bool(forKey: "LCStrictHiding") {
                appListsToConsider.append(sharedModel.hiddenApps)
            }
            let appToLaunch = appListsToConsider.joined().first { app in
                let schemes = app.appInfo.urlSchemes().map { Array($0) } ?? []
                return schemes.contains { $0 as? String == scheme }
            }
            guard let appToLaunch else {
                errorMessage = "lc.appList.schemeCannotOpenError %@".localizeWithFormat(scheme)
                return
            }

            if appToLaunch.appInfo.isLocked && !sharedModel.isHiddenAppUnlocked {
                do {
                    guard try await LCUtils.authenticateUser() else {
                        return
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }

            do {
                try await appToLaunch.runApp(urlStr: url.absoluteString)
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        webPageURL = url
        if isShowingWebPage {
            // Close the browser and open it again on the new page.
            isShowingWebPage = false
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                isShowingWebPage = true
            }
        } else {
            isShowingWebPage = true
        }
    }
}

extension AppLaunchCoordinator: LCAppModelDelegate {
    func closeNavigationView() {
        appSettingsCloseRequests += 1
    }

    /// Moves an app between the Home Screen and the hidden apps after it was
    /// hidden or shown. A hidden app's URL schemes stop counting as zContainer's.
    func changeAppVisibility(app: LCAppModel) {
        let schemes = app.appInfo.urlSchemes().map { Array($0) } ?? []
        let guestURLSchemes = UserDefaults.lcShared().mutableArrayValue(forKey: "LCGuestURLSchemes")
        if app.appInfo.isHidden {
            sharedModel.apps.removeAll { $0 == app }
            if !sharedModel.hiddenApps.contains(app) {
                sharedModel.hiddenApps.append(app)
            }
            guestURLSchemes.removeObjects(in: schemes)
        } else {
            sharedModel.hiddenApps.removeAll { $0 == app }
            if !sharedModel.apps.contains(app) {
                sharedModel.apps.append(app)
            }
            guestURLSchemes.addObjects(from: schemes)
        }
    }

    func jitLaunch(appName: String, classicMode: UInt) async {
        await jitLaunch(withScript: "", appName: appName, classicMode: classicMode)
    }

    /// Asks the JIT enabler set in Settings to attach to the app, shows its log
    /// while it works, and launches the app the classic way when the person
    /// taps Launch Now. Cancel stops waiting and forgets the app to launch.
    func jitLaunch(withScript script: String, appName: String, classicMode: UInt) async {
        jitLog = ""
        let enableJITTask = Task {
            _ = await LCUtils.askForJIT(withScript: script, appName: appName, classicMode: classicMode) { message in
                Task { @MainActor in
                    self.jitLog += "\(message)\n"
                }
            }
        }
        sharedModel.isJITModalOpen = true
        let shouldLaunch = await jitPrompt.ask() ?? false
        sharedModel.isJITModalOpen = false
        guard shouldLaunch else {
            UserDefaults.standard.removeObject(forKey: "selected")
            enableJITTask.cancel()
            return
        }
        LCSharedUtils.launchToGuestApp(withClassicMode: classicMode)
    }

    /// Asks the JIT enabler to attach to an app already running in a
    /// multitasking window, by its process ID: StikDebug or StosDebug, either
    /// installed on the iPhone or inside zContainer as a shared app.
    func jitLaunch(withPID pid: Int, withScript script: String?, appName: String) async {
        guard let jitEnabler = JITEnablerType(rawValue: LCUtils.appGroupUserDefault.integer(forKey: "LCJITEnablerType")) else {
            return
        }
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let encodedData = script?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        if jitEnabler == .StosDebug || jitEnabler == .StosDebugLC {
            let encoded = encodedData.map { "&script=\($0)" } ?? ""
            if jitEnabler == .StosDebugLC {
                guard hasSharedApp(withScheme: "stosdebug") else {
                    errorMessage = "StosDebug is not found. Please install it first and switch it to shared app."
                    return
                }
                if let url = URL(string: "stosdebug://enableJIT?bundleId=\(bundleIdentifier)&appName=\(appName)&pid=\(pid)&relaunchApp=false& forcePID=true\(encoded)") {
                    Task { await openWebView(urlString: url.absoluteString) }
                }
            } else if let url = URL(string: "stosdebug://enableJIT?bundleId=\(bundleIdentifier)&appName=\(appName)&pid=\(pid)&forcePID=true\(encoded)") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return
        }

        let encoded = encodedData.map { "&script-data=\($0)" } ?? ""
        guard let url = URL(string: "stikjit://enable-jit?bundle-id=\(bundleIdentifier)&pid=\(pid)\(encoded)") else {
            return
        }
        if jitEnabler == .StikJITLC {
            guard hasSharedApp(withScheme: "stikjit") else {
                errorMessage = "StikDebug is not found. Please install it first and switch it to shared app."
                return
            }
            Task { await openWebView(urlString: url.absoluteString) }
        } else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func showRunWhenMultitaskAlert() async -> Bool? {
        await runWhenMultitaskPrompt.ask()
    }

    /// Whether an app inside zContainer declares the URL scheme and can run
    /// here: in a secondary zContainer, only shared apps can.
    private func hasSharedApp(withScheme scheme: String) -> Bool {
        sharedModel.apps.contains { app in
            app.appInfo.urlSchemes().contains(scheme) && (sharedModel.multiLCStatus != 2 || app.appInfo.isShared)
        }
    }
}
