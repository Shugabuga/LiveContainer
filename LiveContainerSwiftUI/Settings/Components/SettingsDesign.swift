//
//  SettingsDesign.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The look of zContainer's Settings in one place, matched to the Settings
/// app. Sizes are in points at the default text size; the views scale them
/// with Dynamic Type.
enum SettingsDesign {
    // MARK: Row icons

    /// The colored tile beside a row, and an app's icon in the Apps list.
    static let iconSize = 30.0
    /// How much of a tile its symbol takes up, across and down.
    static let glyphRatio = 0.62
    /// A tile's or an icon's corner radius, as a fraction of its size: the
    /// shape of an app icon.
    static let iconCornerRatio = 0.225
    /// The hairline around an app's icon, which keeps white icons apart from
    /// the white rows.
    static let iconOutlineWidth = 0.5

    // MARK: The Zeus card

    /// The Zeus mark in the card at the top of Settings, as big as the Apple
    /// Account's picture is in the Settings app.
    static let cardMarkSize = 60.0
    /// The Zeus mark at the top of the Zeus page.
    static let headerMarkSize = 88.0
    /// How much of the Zeus mark's tile the bolt takes up.
    static let boltRatio = 0.56
    /// The tile behind the bolt, as on Zeus's app icon.
    static let zeusTile = Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x16 / 255)
    /// Zeus's pink, the color of the bolt.
    static let zeusPink = Color(red: 0xDA / 255, green: 0x2D / 255, blue: 0x98 / 255)
    /// Space between the mark and the text beside it.
    static let cardSpacing = 14.0
    /// Space between a title and the line under it.
    static let subtitleSpacing = 2.0
    /// Extra space above and below the card's content, which makes the card
    /// taller than the rows under it, as the Apple Account card is.
    static let cardPadding = 4.0
    /// Space between the parts of the Zeus page's header.
    static let headerSpacing = 8.0

    // MARK: Badges and checks

    /// The height of the red badge on a row that needs attention.
    static let badgeSize = 24.0
    /// The space at each end of a badge's number, as a fraction of its height.
    static let badgePaddingRatio = 0.3
}
