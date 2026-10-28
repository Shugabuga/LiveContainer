//
//  CertificateOffer.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A certificate sent to zContainer that ZSign opened with its password and
/// that belongs to zContainer's own team, while the person is asked whether
/// zContainer should sign apps with it.
struct CertificateOffer: Equatable {
    let certificate: CertificateLink
    /// The team the certificate belongs to.
    let teamID: String
    /// Whether zContainer already has a certificate, which this one replaces.
    let replacesCurrent: Bool
    /// How the certificate reached zContainer.
    let source: CertificateSource
}
