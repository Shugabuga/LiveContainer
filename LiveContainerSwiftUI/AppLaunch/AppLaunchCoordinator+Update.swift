//
//  AppLaunchCoordinator+Update.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Replacing an installed app with another copy of it: which copy an update
/// from Zeus replaces, the checks and the question before it, and the swap
/// that keeps the app's data and settings.
extension AppLaunchCoordinator {
    /// Decides where an app Zeus sent goes. With no copy installed, it
    /// installs as a new app without asking. Otherwise it replaces the copy in
    /// `replacesFolder`, else the only copy on the Home Screen, else the only
    /// hidden copy, else the copy the person picks from several. Face ID comes
    /// first when that copy is locked or hidden, then the check that it isn't
    /// open, then the one-tap question, worded as an update, a downgrade or a
    /// reinstall.
    /// - Returns: Where the app goes, or nil when the person kept what was
    ///   installed.
    /// - Throws: `AppInstallError.running` when the copy is open, or why
    ///   Face ID couldn't run.
    func updateTarget(for incoming: LCAppInfo, bundleIdentifier: String, folderStem: String, replacesFolder: String?) async throws -> AppReplaceOption? {
        let visible = sharedModel.apps.filter { $0.appInfo.bundleIdentifier() == bundleIdentifier }
        let hidden = sharedModel.hiddenApps.filter { $0.appInfo.bundleIdentifier() == bundleIdentifier }

        let target: LCAppModel
        if let replacesFolder, let named = (visible + hidden).first(where: { $0.appInfo.relativeBundlePath == replacesFolder }) {
            guard try await unlock([named]) else {
                return nil
            }
            target = named
        } else {
            let copies = visible.isEmpty ? hidden : visible
            guard !copies.isEmpty else {
                return AppReplaceOption(isReplace: false, nameOfFolderToInstall: newAppFolderName(for: folderStem))
            }
            // The question names every copy, so Face ID comes first.
            guard try await unlock(copies) else {
                return nil
            }
            if copies.count == 1 {
                target = copies[0]
            } else {
                let options = copies.map {
                    AppReplaceOption(isReplace: true, nameOfFolderToInstall: $0.appInfo.relativeBundlePath, appToReplace: $0)
                }
                guard let picked = await askWhichToReplace(options)?.appToReplace else {
                    return nil
                }
                target = picked
            }
        }

        try checkNotRunning(target)
        guard await confirm(confirmation(forReplacing: target, with: incoming)) else {
            return nil
        }
        return AppReplaceOption(isReplace: true, nameOfFolderToInstall: target.appInfo.relativeBundlePath, appToReplace: target)
    }

    /// Throws `AppInstallError.running` when the app is open through any of
    /// its containers: starting up in zContainer, in a multitasking window, or
    /// in another zContainer.
    func checkNotRunning(_ app: LCAppModel) throws {
        let folderNames = app.uiContainers.map(\.folderName)
        var isRunning = app.isAppRunning
            || folderNames.contains { LCSharedUtils.getContainerUsingLCScheme(withFolderName: $0) != nil }
        if #available(iOS 16.0, *) {
            isRunning = isRunning || folderNames.contains { MultitaskManager.isUsing(container: $0) }
        }
        if isRunning {
            throw AppInstallError.running(appName: app.displayName)
        }
    }

    /// The question before `target` is replaced by the app in `incoming`,
    /// from the two copies' versions and builds.
    func confirmation(forReplacing target: LCAppModel, with incoming: LCAppInfo) -> AppUpdateConfirmation {
        AppUpdateConfirmation(
            appName: target.displayName,
            installedVersion: target.appInfo.version() ?? "",
            installedBuild: Self.build(of: target.appInfo),
            incomingVersion: incoming.version() ?? "",
            incomingBuild: Self.build(of: incoming)
        )
    }

    /// Puts the unpacked app at `source` in the place of `target`, keeping its
    /// data and settings. The new app moves in beside the old one, takes the
    /// old app's settings there and saves them, and only then do the two
    /// folders swap places (`AppBundleSwap`), so whenever zContainer stops,
    /// the folder holds one whole app with the link to its data. The app
    /// left over, the old one or the new one when it can't go in, is deleted
    /// off the main actor.
    /// - Returns: The new app, at the old app's path, still to be signed.
    func replaceBundle(of target: LCAppModel, withAppAt source: URL) async throws -> LCAppInfo {
        let fileManager = FileManager.default
        let folderName: String = target.appInfo.relativeBundlePath
        let applications = target.uiIsShared ? LCPath.lcGroupBundlePath : LCPath.bundlePath
        let destination = applications.appending(path: folderName, directoryHint: .isDirectory)
        let staged = AppBundleSwap.stagedURL(for: destination)

        // One left by an install that stopped halfway.
        try? fileManager.removeItem(at: staged)
        try fileManager.moveItem(at: source, to: staged)
        do {
            guard let stagedApp = LCAppInfo(bundlePath: staged.path) else {
                throw "lc.appList.appInfoInitError".loc
            }
            stagedApp.relativeBundlePath = folderName
            Self.carrySettings(from: target, to: stagedApp)
            // From the swap on, the old app's settings file is gone and its
            // path holds the new app's, so the old app mustn't write it.
            target.appInfo.autoSaveDisabled = true
            try await AppBundleSwap.swap(staged: staged, into: destination)
        } catch {
            // The swap didn't happen, so `staged` holds the new app.
            target.appInfo.autoSaveDisabled = false
            await AppBundleSwap.remove(staged)
            throw error
        }

        guard let newApp = LCAppInfo(bundlePath: destination.path) else {
            throw "lc.appList.appInfoInitError".loc
        }
        newApp.relativeBundlePath = folderName
        newApp.isShared = target.appInfo.isShared
        return newApp
    }

    /// Asks for Face ID before an install names a locked or hidden app,
    /// unless hidden apps are unlocked already. Returns whether the person
    /// got through.
    private func unlock(_ apps: [LCAppModel]) async throws -> Bool {
        guard !sharedModel.isHiddenAppUnlocked,
              apps.contains(where: { $0.appInfo.isLocked || $0.appInfo.isHidden }) else {
            return true
        }
        return try await LCUtils.authenticateUser()
    }

    /// Gives the new app the old one's settings and saves them in one write:
    /// what links it to its data and how it runs, its remark and 32-bit
    /// emulator, and Don't Sign when the old app or Settings asks for it. The
    /// install date becomes today's, as for any install.
    private static func carrySettings(from oldApp: LCAppModel, to newApp: LCAppInfo) {
        let old = oldApp.appInfo
        newApp.autoSaveDisabled = true
        newApp.isLocked = old.isLocked
        newApp.isHidden = old.isHidden
        newApp.isJITNeeded = old.isJITNeeded
        newApp.isShared = old.isShared
        newApp.spoofSDKVersion = old.spoofSDKVersion
        newApp.doSymlinkInbox = old.doSymlinkInbox
        newApp.containerInfo = old.containerInfo
        newApp.tweakFolder = old.tweakFolder
        newApp.selectedLanguage = old.selectedLanguage
        newApp.dataUUID = old.dataUUID
        newApp.orientationLock = old.orientationLock
        newApp.dontInjectTweakLoader = old.dontInjectTweakLoader
        newApp.hideLiveContainer = old.hideLiveContainer
        newApp.hideHomeButton = old.hideHomeButton
        newApp.dontLoadTweakLoader = old.dontLoadTweakLoader
        newApp.doUseLCBundleId = old.doUseLCBundleId
        newApp.fixFilePickerNew = old.fixFilePickerNew
        newApp.fixLocalNotification = old.fixLocalNotification
        newApp.lastLaunched = old.lastLaunched
        newApp.jitLaunchScriptJs = old.jitLaunchScriptJs
        newApp.multitaskSpecified = old.multitaskSpecified
        newApp.classicMode = old.classicMode
        newApp.remark = old.remark
        newApp.selected32BitEmulator = old.selected32BitEmulator
        if oldApp.uiDontSign || LCUtils.appGroupUserDefault.bool(forKey: "LCDontSignApp") {
            newApp.dontSign = true
        }
        newApp.installationDate = Date.now
        newApp.autoSaveDisabled = false
        newApp.save()
    }

    /// Gives the new app what changed on the old one while it signed. The old
    /// app's icon, menu and settings work until the new app takes its place,
    /// but since the swap the old app doesn't save, so each setting that
    /// changed since `settingsAtSwap` is copied over and saved in one write.
    /// Use zContainer's Bundle ID goes through its setter, which rewrites the
    /// new app's Info.plist from its own copy, since the old app's setter
    /// wrote the old app's Info.plist there.
    static func carryChanges(from oldApp: LCAppInfo, since settingsAtSwap: NSDictionary, to newApp: LCAppInfo) {
        let settingsNow: NSDictionary = oldApp.info()
        guard !settingsAtSwap.isEqual(settingsNow) else {
            return
        }
        let bundleIDKeys: Set<String> = ["doUseLCBundleId", "LCOrignalBundleIdentifier"]
        let newInfo: NSMutableDictionary = newApp.info()
        for case let (key as String, value) in settingsNow where !bundleIDKeys.contains(key) {
            if !((settingsAtSwap[key] as AnyObject?)?.isEqual(value) ?? false) {
                newInfo[key] = value
            }
        }
        for case let key as String in settingsAtSwap.allKeys where settingsNow[key] == nil && !bundleIDKeys.contains(key) {
            newInfo.removeObject(forKey: key)
        }
        newApp.autoSaveDisabled = true
        let usedBundleID = (settingsAtSwap["doUseLCBundleId"] as? NSNumber)?.boolValue ?? false
        if oldApp.doUseLCBundleId != usedBundleID {
            newApp.doUseLCBundleId = oldApp.doUseLCBundleId
        }
        newApp.autoSaveDisabled = false
        newApp.save()
    }

    /// An app's build (CFBundleVersion), read from its Info.plist, since
    /// LCAppInfo only gives its version. Nil when it has none.
    private static func build(of appInfo: LCAppInfo) -> String? {
        ZeusGroup.versions(ofAppAt: appInfo.bundlePath()).build
    }
}
