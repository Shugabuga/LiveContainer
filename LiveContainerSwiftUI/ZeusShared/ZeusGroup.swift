//
//  ZeusGroup.swift
//  LiveContainerSwiftUI
//

import Foundation

/// zContainer's side of the app group it shares with Zeus (see
/// ZeusGroupLayout). Zeus leaves apps and its certificate there as requests
/// and opens zContainer with a zeus-request link naming them; zContainer
/// writes back a result for each, and the list of apps it holds.
///
/// Every app the group is given to can write in it, guest apps included, so
/// nothing read from it is trusted: each path is checked without following
/// symbolic links, the files Zeus wrote must be regular files within their
/// size limits, folder names come only from parsed ids, and nothing read is
/// run, opened as a link or used as a path outside the group.
enum ZeusGroup {
    /// The group's folder, when zContainer shares an app group with Zeus.
    static var root: URL? {
        guard LCSharedUtils.sharesZeusGroup() else {
            return nil
        }
        return LCSharedUtils.appGroupPath()
    }

    // MARK: Taken requests

    /// Kept in the standard defaults: a second zContainer in the group takes
    /// no requests, and keeps its own list.
    private static let takenKey = "ZCTakenZeusRequests"

    /// Whether zContainer took this request already, from a link or a
    /// rescan, so it is never handled twice.
    @MainActor
    static func hasTaken(_ id: UUID) -> Bool {
        takenIDs.contains(id.uuidString)
    }

    /// Remembers that zContainer took a request. Only the newest 200 are
    /// kept, which is far more than a day of requests.
    @MainActor
    static func markTaken(_ id: UUID) {
        var ids = takenIDs.filter { $0 != id.uuidString }
        ids.append(id.uuidString)
        UserDefaults.standard.set(Array(ids.suffix(ZeusGroupLayout.takenLimit)), forKey: takenKey)
    }

    private static var takenIDs: [String] {
        UserDefaults.standard.stringArray(forKey: takenKey) ?? []
    }

    // MARK: Paths

    /// Zeus's folder in the group.
    static func zeusFolder(in root: URL) -> URL {
        root.appending(path: ZeusGroupLayout.zeusFolderName, directoryHint: .isDirectory)
    }

    /// Zeus/Requests, which holds a folder for each request.
    static func requestsFolder(in root: URL) -> URL {
        zeusFolder(in: root).appending(path: ZeusGroupLayout.requestsFolderName, directoryHint: .isDirectory)
    }

    /// zContainer's own folder in the group.
    static func ownFolder(in root: URL) -> URL {
        root.appending(path: ZeusGroupLayout.zContainerFolderName, directoryHint: .isDirectory)
    }

    /// zContainer/Results, which holds a result for each request answered.
    static func resultsFolder(in root: URL) -> URL {
        ownFolder(in: root).appending(path: ZeusGroupLayout.resultsFolderName, directoryHint: .isDirectory)
    }

    /// The result of a request, named by its id.
    static func resultFile(for id: UUID, in root: URL) -> URL {
        resultsFolder(in: root)
            .appending(path: id.uuidString, directoryHint: .notDirectory)
            .appendingPathExtension(ZeusGroupLayout.resultFileExtension)
    }

    /// zContainer/Apps.json.
    static func manifestFile(in root: URL) -> URL {
        ownFolder(in: root).appending(path: ZeusGroupLayout.manifestFileName, directoryHint: .notDirectory)
    }

    // MARK: Reading what is there

    /// The attributes of whatever is at a path, read without following a
    /// symbolic link there, or nil when nothing is.
    static func attributes(at url: URL) -> [FileAttributeKey: Any]? {
        try? FileManager.default.attributesOfItem(atPath: url.path)
    }

    /// What is at a path, without following a symbolic link there, or nil
    /// when nothing is.
    static func itemType(at url: URL) -> FileAttributeType? {
        attributes(at: url)?[.type] as? FileAttributeType
    }

    /// Reads a file Zeus wrote: a regular file of at most `limit` bytes. It
    /// is opened without following a symbolic link or waiting on a pipe, and
    /// checked again once open, so nothing put in its place after the first
    /// check is read either.
    static func readZeusFile(at url: URL, limit: Int) throws -> Data {
        guard itemType(at: url) == .typeRegular else {
            throw ZeusGroupError.unreadable
        }
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else {
            throw ZeusGroupError.unreadable
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var status = stat()
        guard fstat(descriptor, &status) == 0,
              status.st_mode & S_IFMT == S_IFREG,
              status.st_size <= Int64(limit) else {
            throw ZeusGroupError.unreadable
        }
        // One byte more than allowed, to notice a file that grew since.
        guard let data = try? handle.read(upToCount: limit + 1), data.count <= limit else {
            throw ZeusGroupError.unreadable
        }
        return data
    }

    // MARK: Writing zContainer's side

    /// Makes one of zContainer's own folders when it is missing. Anything
    /// else found under its name is removed first, a symbolic link without
    /// what it points to, since only zContainer writes there. Apps.json is
    /// written off the main actor, and a second zContainer answers requests
    /// too, so another writer may remove or make the folder meanwhile.
    static func prepareOwnFolder(_ url: URL) throws {
        let fileManager = FileManager.default
        switch itemType(at: url) {
        case .typeDirectory?:
            return
        case nil:
            break
        default:
            do {
                try fileManager.removeItem(at: url)
            } catch {
                switch itemType(at: url) {
                case .typeDirectory?:
                    return
                case nil:
                    break
                default:
                    throw error
                }
            }
        }
        do {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: false,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        } catch {
            guard itemType(at: url) == .typeDirectory else {
                throw error
            }
        }
    }

    /// Writes one of zContainer's own files in one step, so Zeus never reads
    /// half of it. Anything but a regular file found under its name is
    /// removed first, a symbolic link without what it points to.
    static func writeOwnFile(_ data: Data, to url: URL) throws {
        if let type = itemType(at: url), type != .typeRegular {
            try FileManager.default.removeItem(at: url)
        }
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: JSON

    /// Reads JSON the way both sides write it, with ISO 8601 dates.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Writes JSON the way both sides read it, with ISO 8601 dates.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
