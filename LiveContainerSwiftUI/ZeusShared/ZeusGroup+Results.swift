//
//  ZeusGroup+Results.swift
//  LiveContainerSwiftUI
//

import Foundation

extension ZeusGroup {
    /// Whether zContainer answered this request already.
    static func hasResult(for id: UUID) -> Bool {
        guard let root else {
            return false
        }
        return itemType(at: resultFile(for: id, in: root)) == .typeRegular
    }

    /// Writes zContainer's answer to a request, in one step, for Zeus to read
    /// the next time it becomes active. zContainer/ and Results/ are made
    /// again when they are missing or something else stands in their place.
    /// A failure is only logged: Zeus treats a request without an answer as
    /// unanswered until it expires.
    static func writeResult(_ result: ZeusRequestResult) {
        guard let root else {
            return
        }
        do {
            try prepareOwnFolder(ownFolder(in: root))
            try prepareOwnFolder(resultsFolder(in: root))
            let data = try makeEncoder().encode(result)
            guard data.count <= ZeusGroupLayout.maxResultSize else {
                NSLog("[LC] Didn't write the result of Zeus's request %@: it is %ld bytes", result.id.uuidString, data.count)
                return
            }
            try writeOwnFile(data, to: resultFile(for: result.id, in: root))
        } catch {
            NSLog("[LC] Couldn't write the result of Zeus's request %@: %@", result.id.uuidString, error.localizedDescription)
        }
    }

    /// Deletes results older than 7 days, which Zeus has read or stopped
    /// waiting for, and anything in Results/ that isn't a result. zContainer/
    /// or Results/ found as anything but a folder is removed, and made again
    /// by the next result.
    static func sweepResults(now: Date = .now) {
        guard let root else {
            return
        }
        let fileManager = FileManager.default
        let results = resultsFolder(in: root)
        for folder in [ownFolder(in: root), results] {
            guard let type = itemType(at: folder) else {
                return
            }
            guard type == .typeDirectory else {
                try? fileManager.removeItem(at: folder)
                return
            }
        }

        let names = (try? fileManager.contentsOfDirectory(atPath: results.path)) ?? []
        for name in names {
            let item = results.appending(path: name, directoryHint: .notDirectory)
            let found = attributes(at: item)
            let isResult = isResultName(name) && found?[.type] as? FileAttributeType == .typeRegular
            let writtenAt = found?[.modificationDate] as? Date ?? .distantPast
            if !isResult || now.timeIntervalSince(writtenAt) > ZeusGroupLayout.resultLifetime {
                try? fileManager.removeItem(at: item)
            }
        }
    }

    /// Whether a name is one a result is written under: a request id with
    /// the result extension.
    private static func isResultName(_ name: String) -> Bool {
        let suffix = "." + ZeusGroupLayout.resultFileExtension
        return name.hasSuffix(suffix) && ZeusGroupRules.isRequestID(String(name.dropLast(suffix.count)))
    }
}
