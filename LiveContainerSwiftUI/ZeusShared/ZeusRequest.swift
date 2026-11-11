//
//  ZeusRequest.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A request Zeus left in the shared app group, read from
/// Zeus/Requests/ID/request.json: an app to install, or Zeus's certificate.
/// ZeusGroup.readRequest returns one only once every field passed its
/// check, and the app it sends is checked again once copied.
struct ZeusRequest: Decodable, Equatable, Sendable {
    let format: Int
    let id: UUID
    let kind: ZeusRequestKind
    let createdAt: Date
    /// The file next to request.json that carries the app or the
    /// certificate, which matches the kind.
    let payload: String

    // MARK: App requests only

    let bundleIdentifier: String?
    /// The app's name as Zeus shows it, cut to the contract's limits.
    let name: String?
    /// The folder of the copy in zContainer the app replaces, when Zeus
    /// knows it from Apps.json.
    let replacesFolder: String?
    /// The size of app.ipa in bytes, and its SHA-256.
    let size: Int64?
    let sha256: String?
}

extension ZeusRequest {
    private enum CodingKeys: String, CodingKey {
        case format, id, kind, createdAt, payload
        case bundleIdentifier, name, replacesFolder, size, sha256
    }

    /// Decodes request.json. The id has to be written the way Zeus writes
    /// it, in uppercase, since it also names the request's folder.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        guard ZeusGroupRules.isRequestID(idString), let id = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Not a request id")
        }
        self.id = id
        format = try container.decode(Int.self, forKey: .format)
        kind = try container.decode(ZeusRequestKind.self, forKey: .kind)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        payload = try container.decode(String.self, forKey: .payload)
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            .map { ZeusGroupRules.clipped($0, to: ZeusGroupLayout.maxStringLength) }
        replacesFolder = try container.decodeIfPresent(String.self, forKey: .replacesFolder)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        sha256 = try container.decodeIfPresent(String.self, forKey: .sha256)
    }
}
