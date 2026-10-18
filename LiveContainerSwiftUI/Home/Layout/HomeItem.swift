//
//  HomeItem.swift
//  LiveContainerSwiftUI
//

import Foundation

/// One icon on the Home Screen: an app inside zContainer, or zContainer's own
/// Settings. The layout saves each item as its `id`.
enum HomeItem: Hashable, Identifiable, Sendable {
    /// An installed app, by its key: its bundle ID and the folder it is
    /// installed in, as `bundleId:relativeBundlePath`. The key stays the same
    /// when the app is replaced by a new version or moved between private and
    /// shared storage, so the icon keeps its place.
    case app(String)

    /// zContainer's Settings. It can be moved but not removed.
    case settings

    /// The text the layout is saved as: `settings`, or `app:` and the app's key.
    var id: String {
        switch self {
        case .app(let key):
            "app:\(key)"
        case .settings:
            "settings"
        }
    }

    /// Reads an item from the text `id` makes. Returns nil for text that
    /// names neither an app nor Settings.
    init?(id: String) {
        if id == "settings" {
            self = .settings
        } else if id.hasPrefix("app:"), id.count > 4 {
            self = .app(String(id.dropFirst(4)))
        } else {
            return nil
        }
    }
}

extension HomeItem: Codable {
    /// Reads an item saved as its `id`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(String.self)
        guard let item = HomeItem(id: id) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(id) is not a Home Screen item")
        }
        self = item
    }

    /// Saves the item as its `id`, which keeps the saved layout short and readable.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}
