//
//  ZeusConnection+Link.swift
//  LiveContainerSwiftUI
//

import Foundation

/// How zContainer stands with Zeus, as onboarding's Connect to Zeus step
/// ticks it off: Zeus is installed, a certificate that can sign is stored,
/// and it belongs to the team that signed zContainer. The certificate is
/// what signing takes; Zeus being installed only matters for sending apps
/// and signing zContainer again.
extension ZeusConnection {
    /// Whether the certificate belongs to the team that signed zContainer:
    /// false when Zeus's certificate was left out for belonging to another
    /// team, and nil until both teams are known.
    var isSameTeam: Bool? {
        if mismatchedTeamID != nil {
            return false
        }
        guard hasCertificate, let teamID, let ownTeamID else {
            return nil
        }
        return teamID == ownTeamID
    }

    /// Whether the stored certificate can sign apps, as far as is known
    /// without signing anything: it hasn't expired, Apple hasn't revoked it,
    /// and storing or checking it found nothing wrong.
    var isCertificateUsable: Bool {
        hasCertificate && !isExpired && validity != .revoked && problem == nil
    }

    /// Whether zContainer can sign apps, as far as is known without signing
    /// anything: a usable certificate of its own team is stored, whether
    /// Zeus put it inside or it was imported by hand.
    var isReadyToSign: Bool {
        isCertificateUsable && isSameTeam == true
    }

    /// Whether zContainer is connected to Zeus: Zeus is installed, and
    /// zContainer is ready to sign.
    var isConnected: Bool {
        isZeusInstalled && isReadyToSign
    }
}
