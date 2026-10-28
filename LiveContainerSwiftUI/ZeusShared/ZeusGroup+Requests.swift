//
//  ZeusGroup+Requests.swift
//  LiveContainerSwiftUI
//

import CryptoKit
import Foundation

extension ZeusGroup {
    /// The ids of the requests in Zeus/Requests, oldest first: the folders
    /// named by an id. Folders Zeus is still filling, and anything else found
    /// there, are left out.
    static func requestIDsOnDisk() -> [UUID] {
        guard let root else {
            return []
        }
        let requests = requestsFolder(in: root)
        guard itemType(at: zeusFolder(in: root)) == .typeDirectory, itemType(at: requests) == .typeDirectory else {
            return []
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: requests.path)) ?? []
        let folders = names.compactMap { name -> (id: UUID, createdAt: Date)? in
            guard ZeusGroupRules.isRequestID(name),
                  let id = UUID(uuidString: name),
                  let folder = attributes(at: requests.appending(path: name, directoryHint: .isDirectory)),
                  folder[.type] as? FileAttributeType == .typeDirectory else {
                return nil
            }
            return (id, folder[.creationDate] as? Date ?? .distantPast)
        }
        return folders
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
            .map(\.id)
    }

    /// Reads and checks the request with this id. `fromLink` says whether a
    /// zeus-request link from Zeus named it rather than a rescan.
    ///
    /// Throws `missing` when there is no folder for it, `expired` when it is
    /// too old or dated too far ahead, and `unreadable` when request.json is
    /// missing, too large or doesn't follow the contract, or when the app it
    /// sends isn't a regular file within the size limit.
    static func readRequest(_ id: UUID, fromLink: Bool, now: Date = .now) throws -> ZeusRequest {
        let folder = try requestFolder(for: id)
        let data = try readZeusFile(
            at: folder.appending(path: ZeusGroupLayout.requestFileName, directoryHint: .notDirectory),
            limit: ZeusGroupLayout.maxRequestSize
        )
        guard let request = try? makeDecoder().decode(ZeusRequest.self, from: data),
              request.format == ZeusGroupLayout.format,
              request.id == id,
              request.payload == request.kind.payloadFileName else {
            throw ZeusGroupError.unreadable
        }

        let age = now.timeIntervalSince(request.createdAt)
        guard age >= -ZeusGroupLayout.futureSkew, age <= request.kind.lifetime(fromLink: fromLink) else {
            throw ZeusGroupError.expired
        }

        if request.kind == .app {
            let app = attributes(at: folder.appending(path: ZeusGroupLayout.appPayloadFileName, directoryHint: .notDirectory))
            guard hasValidAppFields(request),
                  app?[.type] as? FileAttributeType == .typeRegular,
                  let size = (app?[.size] as? NSNumber)?.int64Value,
                  size <= ZeusGroupLayout.maxAppPayloadSize else {
                throw ZeusGroupError.unreadable
            }
        }
        return request
    }

    /// Copies the app an app request sends into `folder`, as app.ipa, and
    /// returns the copy. The copy, which APFS makes without duplicating the
    /// data, must have the size and SHA-256 Zeus gave, or it is deleted and
    /// `damaged` thrown. The copy is what gets checked, so what installs is
    /// what was checked. This only guards against a damaged or incomplete
    /// file; whoever can write the request can write its checksum too.
    @concurrent
    nonisolated static func copyAppPayload(of request: ZeusRequest, into folder: URL) async throws -> URL {
        guard request.kind == .app, let size = request.size, let sha256 = request.sha256 else {
            throw ZeusGroupError.unreadable
        }
        let source = try requestFolder(for: request.id)
            .appending(path: ZeusGroupLayout.appPayloadFileName, directoryHint: .notDirectory)
        guard itemType(at: source) == .typeRegular else {
            throw ZeusGroupError.unreadable
        }

        let fileManager = FileManager.default
        let copy = folder.appending(path: ZeusGroupLayout.appPayloadFileName, directoryHint: .notDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        if itemType(at: copy) != nil {
            try fileManager.removeItem(at: copy)
        }
        try fileManager.copyItem(at: source, to: copy)
        do {
            let copied = attributes(at: copy)
            guard copied?[.type] as? FileAttributeType == .typeRegular,
                  (copied?[.size] as? NSNumber)?.int64Value == size,
                  try sha256Digest(of: copy) == sha256 else {
                throw ZeusGroupError.damaged
            }
        } catch {
            try? fileManager.removeItem(at: copy)
            throw error
        }
        return copy
    }

    /// Reads the certificate a certificate request sends. ZeusCertificate.plist
    /// is deleted as soon as it has been read, whatever it holds, so the
    /// private key doesn't stay in the group. Throws `unreadable` unless the
    /// file is a property list with Protocol 1, a Certificate, a Password, a
    /// TeamID and a SerialNumber.
    static func takeCertificate(of request: ZeusRequest) throws -> ZeusCertificatePayload {
        guard request.kind == .certificate else {
            throw ZeusGroupError.unreadable
        }
        let file = try requestFolder(for: request.id)
            .appending(path: ZeusGroupLayout.certificatePayloadFileName, directoryHint: .notDirectory)
        defer {
            if itemType(at: file) != nil {
                try? FileManager.default.removeItem(at: file)
            }
        }

        let data = try readZeusFile(at: file, limit: ZeusGroupLayout.maxCertificateSize)
        let isWithinLimit = { (string: String) in string.count <= ZeusGroupLayout.maxStringLength }
        guard let contents = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              contents["Protocol"] as? Int == 1,
              let certificate = contents["Certificate"] as? Data, !certificate.isEmpty,
              let password = contents["Password"] as? String, isWithinLimit(password),
              let teamID = contents["TeamID"] as? String, !teamID.isEmpty, isWithinLimit(teamID),
              let serialNumber = contents["SerialNumber"] as? String, !serialNumber.isEmpty, isWithinLimit(serialNumber) else {
            throw ZeusGroupError.unreadable
        }
        return ZeusCertificatePayload(
            certificate: certificate,
            password: password,
            serialNumber: serialNumber,
            expiresAt: contents["ExpiresAt"] as? Date
        )
    }

    // MARK: Helpers

    /// The folder of a request Zeus finished writing, once Zeus/, Requests/
    /// and the request's own folder all turn out to be real folders rather
    /// than symbolic links.
    private static func requestFolder(for id: UUID) throws -> URL {
        guard let root else {
            throw ZeusGroupError.unreachable
        }
        let folder = requestsFolder(in: root).appending(path: id.uuidString, directoryHint: .isDirectory)
        guard [zeusFolder(in: root), requestsFolder(in: root), folder].allSatisfy({ itemType(at: $0) == .typeDirectory }) else {
            throw ZeusGroupError.missing
        }
        return folder
    }

    /// Whether an app request names what zContainer needs: a valid bundle
    /// ID, a valid folder to replace when it gives one, and the size and
    /// SHA-256 of the app. The name is only shown, so it may be missing.
    private static func hasValidAppFields(_ request: ZeusRequest) -> Bool {
        guard let bundleIdentifier = request.bundleIdentifier, ZeusGroupRules.isBundleIdentifier(bundleIdentifier),
              let size = request.size, (1...ZeusGroupLayout.maxAppPayloadSize).contains(size),
              let sha256 = request.sha256, ZeusGroupRules.isSHA256(sha256) else {
            return false
        }
        return request.replacesFolder.map(ZeusGroupRules.isFolder) ?? true
    }

    /// The SHA-256 of a file as lowercase hexadecimal, read 1 MiB at a time.
    /// Stops with CancellationError when the task is cancelled.
    private static func sha256Digest(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer {
            try? handle.close()
        }
        var hasher = SHA256()
        var isAtEnd = false
        while !isAtEnd {
            try Task.checkCancellation()
            // Each chunk is let go before the next is read, however large
            // the app is.
            try autoreleasepool {
                if let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                    hasher.update(data: chunk)
                } else {
                    isAtEnd = true
                }
            }
        }
        return hasher.finalize().map { byte in
            let digits = String(byte, radix: 16)
            return byte < 0x10 ? "0" + digits : digits
        }.joined()
    }
}
