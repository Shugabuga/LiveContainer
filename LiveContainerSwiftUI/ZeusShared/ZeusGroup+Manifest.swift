//
//  ZeusGroup+Manifest.swift
//  LiveContainerSwiftUI
//

import Foundation

extension ZeusGroup {
    /// The last write of Apps.json started. Each write waits for the one
    /// before it, so an older list never lands after a newer one.
    @MainActor private static var manifestWrite: Task<Void, Never>?

    /// Writes Apps.json, the apps zContainer holds, for Zeus to read the next
    /// time it becomes active. Hidden and locked apps are left out, counted,
    /// and named only by bundle ID, as are apps Zeus couldn't use and any
    /// past the size limits (an app without a valid bundle ID is only
    /// counted), so Zeus can tell an app missing from the list that is still
    /// here from one that was deleted. A second zContainer, which leaves apps
    /// to the first one, writes nothing. The list is taken now; each app's
    /// version is read, and the file written, off the main actor.
    @MainActor
    static func writeManifest(from model: SharedModel) {
        guard model.multiLCStatus != 2, let root else {
            return
        }
        var apps: [(bundlePath: String?, app: ZeusManifestApp)] = []
        var withheld = model.hiddenApps.compactMap { $0.appInfo.bundleIdentifier() }
        for app in model.apps {
            let appInfo = app.appInfo
            // Locked apps are left out and named, like hidden ones, and so
            // is an app Zeus couldn't open or replace by its folder. One
            // without a valid bundle ID is only counted.
            guard !appInfo.isLocked, !app.uiIsLocked,
                  let bundleIdentifier = appInfo.bundleIdentifier(), ZeusGroupRules.isBundleIdentifier(bundleIdentifier),
                  let folder = appInfo.relativeBundlePath, ZeusGroupRules.isFolder(folder) else {
                if let bundleIdentifier = appInfo.bundleIdentifier() {
                    withheld.append(bundleIdentifier)
                }
                continue
            }
            let entry = ZeusManifestApp(
                bundleIdentifier: bundleIdentifier,
                folder: folder,
                name: ZeusGroupRules.clipped(appInfo.displayName() ?? bundleIdentifier, to: ZeusGroupLayout.maxStringLength),
                isShared: appInfo.isShared,
                installedAt: appInfo.installationDate
            )
            apps.append((appInfo.bundlePath(), entry))
        }
        let withheldCount = model.hiddenApps.count + model.apps.count - apps.count
        let host = currentHost()
        let writtenAt = Date.now

        let previous = manifestWrite
        manifestWrite = Task { [apps, withheld] in
            await previous?.value
            await saveManifest(apps, host: host, withheldCount: withheldCount, withheld: withheld, writtenAt: writtenAt, in: root)
        }
    }

    /// The version and build in the Info.plist of the app at a bundle path,
    /// trimmed and cut to 64 characters, with an empty one read as missing:
    /// CFBundleShortVersionString (else CFBundleVersion, as LCAppInfo's
    /// version() reads it) and CFBundleVersion. LCAppInfo's info() holds
    /// zContainer's settings for the app rather than its Info.plist, so the
    /// build comes from the bundle.
    static func versions(ofAppAt bundlePath: String?) -> (version: String?, build: String?) {
        guard let bundlePath,
              let data = try? Data(contentsOf: URL(filePath: bundlePath, directoryHint: .isDirectory)
                .appending(path: "Info.plist", directoryHint: .notDirectory)),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return (nil, nil)
        }
        let clip = { (string: String) -> String? in
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : ZeusGroupRules.clipped(trimmed, to: ZeusGroupLayout.maxVersionLength)
        }
        let build = (info["CFBundleVersion"] as? String).flatMap(clip)
        let version = (info["CFBundleShortVersionString"] as? String).flatMap(clip) ?? build
        return (version, build)
    }

    /// This zContainer, as Apps.json names it.
    private static func currentHost() -> ZeusManifestHost {
        let info = Bundle.main.infoDictionary ?? [:]
        let clip = { (string: String, limit: Int) in ZeusGroupRules.clipped(string, to: limit) }
        return ZeusManifestHost(
            bundleIdentifier: clip(Bundle.main.bundleIdentifier ?? "", ZeusGroupLayout.maxBundleIdentifierLength),
            version: (info["CFBundleShortVersionString"] as? String).map { clip($0, ZeusGroupLayout.maxVersionLength) },
            build: (info["CFBundleVersion"] as? String).map { clip($0, ZeusGroupLayout.maxVersionLength) },
            teamIdentifier: clip(LCSharedUtils.teamIdentifier() ?? "", ZeusGroupLayout.maxStringLength),
            groupIdentifier: clip(LCSharedUtils.appGroupID() ?? "", ZeusGroupLayout.maxStringLength)
        )
    }

    /// Reads each app's version and build, then writes Apps.json in one step.
    /// `withheld` holds the bundle IDs of the hidden, locked and unusable
    /// apps; the ones past the size limits are added here.
    @concurrent
    private nonisolated static func saveManifest(
        _ apps: [(bundlePath: String?, app: ZeusManifestApp)],
        host: ZeusManifestHost,
        withheldCount: Int,
        withheld: [String],
        writtenAt: Date,
        in root: URL
    ) async {
        let listed = apps.prefix(ZeusGroupLayout.maxManifestApps).map { entry in
            var app = entry.app
            let found = versions(ofAppAt: entry.bundlePath)
            app.version = found.version
            app.build = found.build
            return app
        }
        // The apps past the list are always the last ones, since the list
        // only ever loses apps from its end.
        let named = { (listedCount: Int) in
            withheldBundleIdentifiers(from: withheld + apps.dropFirst(listedCount).map(\.app.bundleIdentifier))
        }
        var manifest = ZeusAppsManifest(
            writtenAt: writtenAt,
            host: host,
            withheldCount: withheldCount + apps.count - listed.count,
            withheldBundleIdentifiers: named(listed.count),
            apps: listed
        )
        do {
            let encoder = makeEncoder()
            var data = try encoder.encode(manifest)
            // Only a great many apps with very long names get here: the last
            // ones are left out, counted and named, until the list fits. Each
            // takes more room as an entry than as a bare bundle ID, and the
            // most bundle IDs named fit well within the limit, so it always
            // ends.
            while data.count > ZeusGroupLayout.maxManifestSize, !manifest.apps.isEmpty {
                let count = max(1, manifest.apps.count / 10)
                manifest.apps.removeLast(count)
                manifest.withheldCount += count
                manifest.withheldBundleIdentifiers = named(manifest.apps.count)
                data = try encoder.encode(manifest)
            }
            try prepareOwnFolder(ownFolder(in: root))
            try writeOwnFile(data, to: manifestFile(in: root))
        } catch {
            NSLog("[LC] Couldn't write the list of apps for Zeus: %@", error.localizedDescription)
        }
    }

    /// The bundle IDs Apps.json names for the apps it leaves out: the valid
    /// ones, each once, in the order given, and at most as many as the list
    /// holds apps.
    private nonisolated static func withheldBundleIdentifiers(from bundleIdentifiers: [String]) -> [String] {
        var seen = Set<String>()
        var named: [String] = []
        for bundleIdentifier in bundleIdentifiers {
            guard named.count < ZeusGroupLayout.maxManifestApps else {
                break
            }
            if ZeusGroupRules.isBundleIdentifier(bundleIdentifier), seen.insert(bundleIdentifier).inserted {
                named.append(bundleIdentifier)
            }
        }
        return named
    }
}
