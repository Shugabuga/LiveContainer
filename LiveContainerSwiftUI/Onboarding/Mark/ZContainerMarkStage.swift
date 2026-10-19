//
//  ZContainerMarkStage.swift
//  LiveContainerSwiftUI
//

/// How much of zContainer's icon has come in, as it arrives on the welcome
/// screen. Each stage shows what the ones before it showed, and more.
enum ZContainerMarkStage: Int, Comparable {
    /// Nothing yet.
    case hidden
    /// The near black tile.
    case tile
    /// The container's outline, drawn around the tile.
    case frame
    /// Zeus's bolt inside it: the whole icon.
    case bolt

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
