//
//  PendingInstallStore.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where PendingInstallQueue keeps the apps on their way in, so they outlast
/// zContainer closing, as it does when Zeus signs and installs it again or
/// iOS ends it while the person is in Zeus. Zeus counts an app as sent once
/// its one-time link has been read, so an IPA lost here is lost for good.
///
/// Application Support/ReceivedApps, which updates keep and backups leave
/// out, holds a folder for each app's IPA, named by the app's id, and a
/// manifest of the apps still to install, written again whenever one of
/// them changes.
@MainActor
enum PendingInstallStore {
    private static let root = URL.applicationSupportDirectory.appending(path: "ReceivedApps", directoryHint: .isDirectory)
    private static let manifestName = "Manifest.json"

    private static var manifest: URL {
        root.appending(path: manifestName, directoryHint: .notDirectory)
    }

    /// The folder an app's IPA goes in.
    static func folder(for id: UUID) -> URL {
        root.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    /// Makes the folder an app's IPA goes in, and returns it.
    static func makeFolder(for id: UUID) throws -> URL {
        try makeRoot()
        let folder = folder(for: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Moves an IPA into its app's folder, and returns where it went.
    static func moveIn(_ file: URL, for id: UUID) throws -> URL {
        let destination = try makeFolder(for: id).appending(path: file.lastPathComponent, directoryHint: .notDirectory)
        try FileManager.default.moveItem(at: file, to: destination)
        return destination
    }

    /// Deletes an app's folder, with its IPA.
    static func removeFolder(for id: UUID) {
        try? FileManager.default.removeItem(at: folder(for: id))
    }

    /// Writes down the apps still on their way in, in place of the last list.
    static func save(_ items: [PendingInstall]) {
        let records = items.compactMap(record(for:))
        guard !records.isEmpty else {
            try? FileManager.default.removeItem(at: manifest)
            return
        }
        do {
            try makeRoot()
            try JSONEncoder().encode(records).write(to: manifest, options: .atomic)
        } catch {
            NSLog("[LC] Couldn't write down the apps on their way in: \(error)")
        }
    }

    /// The apps that were still on their way in when zContainer last closed,
    /// as long as their IPAs can still be found. A link whose download
    /// hadn't finished comes back downloading. Folders no app refers to any
    /// more are deleted.
    static func restore() -> [PendingInstall] {
        let records = (try? Data(contentsOf: manifest)).flatMap {
            try? JSONDecoder().decode([PendingInstallRecord].self, from: $0)
        } ?? []
        let items = records.compactMap(item(from:))
        removeFolders(keeping: Set(items.map(\.id.uuidString)))
        save(items)
        return items
    }

    /// Makes ReceivedApps, kept out of backups, since what's in it is gone
    /// once installed.
    private static func makeRoot() throws {
        guard !FileManager.default.fileExists(atPath: root.path) else {
            return
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var folder = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
    }

    /// Deletes everything in ReceivedApps but the manifest and the folders
    /// with these names.
    private static func removeFolders(keeping names: Set<String>) {
        let contents = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        for url in contents where url.lastPathComponent != manifestName && !names.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// What's written down for an app, or nil for one that's done coming in,
    /// or an opened IPA with no bookmark to find it again.
    private static func record(for item: PendingInstall) -> PendingInstallRecord? {
        guard !item.state.isFinished else {
            return nil
        }
        switch item.source {
        case .link(let url):
            return PendingInstallRecord(
                id: item.id,
                kind: .link,
                name: item.placeholderName,
                state: item.state,
                address: url.absoluteString,
                fileName: item.file?.lastPathComponent
            )
        case .pickedFile(let file):
            return PendingInstallRecord(
                id: item.id,
                kind: .pickedFile,
                name: item.placeholderName,
                state: item.state,
                fileName: file.lastPathComponent
            )
        case .openedFile:
            guard let bookmark = item.bookmark else {
                return nil
            }
            return PendingInstallRecord(
                id: item.id,
                kind: .openedFile,
                name: item.placeholderName,
                state: item.state,
                bookmark: bookmark
            )
        }
    }

    /// The app a record describes, or nil when its IPA can't be found.
    private static func item(from record: PendingInstallRecord) -> PendingInstall? {
        guard !record.state.isFinished else {
            return nil
        }
        switch record.kind {
        case .link:
            guard let address = record.address, let url = URL(string: address) else {
                return nil
            }
            // DownloadHelper moves the IPA in only once all of it has come,
            // so one that's there is whole, even when zContainer closed
            // before noting that it had downloaded.
            let fileName = record.fileName ?? PendingInstallSource.downloadName(for: url)
            let file = folder(for: record.id).appending(path: fileName, directoryHint: .notDirectory)
            let isDownloaded = FileManager.default.fileExists(atPath: file.path)
            return PendingInstall(id: record.id, source: .link(url), name: record.name, downloadedFile: isDownloaded ? file : nil)
        case .pickedFile:
            guard let fileName = record.fileName else {
                return nil
            }
            let file = folder(for: record.id).appending(path: fileName, directoryHint: .notDirectory)
            guard FileManager.default.fileExists(atPath: file.path) else {
                return nil
            }
            return PendingInstall(id: record.id, source: .pickedFile(file), name: record.name)
        case .openedFile:
            var isStale = false
            guard let bookmark = record.bookmark,
                  let file = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) else {
                return nil
            }
            return PendingInstall(id: record.id, source: .openedFile(file), name: record.name, bookmark: bookmark)
        }
    }
}
