//
//  ZeusAttention.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Why zContainer can't sign apps right now, which Settings shows as a row
/// with a red badge under the Zeus card, the way the Settings app shows
/// "Finish Setting Up Your iPhone" under the Apple Account.
enum ZeusAttention: Equatable {
    /// No certificate is stored.
    case notSetUp
    /// Storing or checking the certificate went wrong, or Check Setup found
    /// that signing fails.
    case problem
    /// The certificate has expired.
    case expired
    /// Apple revoked the certificate.
    case revoked

    /// The row's text.
    var title: String {
        switch self {
        case .notSetUp:
            "zc.settings.attention.notSetUp".loc
        case .problem:
            "zc.settings.attention.problem".loc
        case .expired:
            "zc.settings.attention.expired".loc
        case .revoked:
            "zc.settings.attention.revoked".loc
        }
    }
}
