//
//  ZeusCommunity.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where the people who use Zeus and zContainer meet: Zeus's Discord server,
/// which Settings > Zeus and the end of onboarding both point to, so the
/// invite lives in one place.
enum ZeusCommunity {
    /// The invite to Zeus's Discord server, the same one Zeus's About page
    /// opens. It opens in Discord when Discord is installed, and in the
    /// browser when it isn't.
    static let discordURL = URL(string: "https://discord.com/invite/nQuFZNwsvd")!
}
