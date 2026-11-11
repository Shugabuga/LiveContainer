//
//  ZeusCertificatePayload.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The certificate a certificate request from Zeus carries, read from its
/// ZeusCertificate.plist, which has the same keys as the one Zeus puts inside
/// the app (LCZeusCertificate.h). The file is deleted as soon as it is read.
struct ZeusCertificatePayload: Sendable {
    /// A PKCS#12 of the signing certificate and its private key.
    let certificate: Data
    let password: String
    /// The certificate's serial number, in hexadecimal.
    let serialNumber: String
    let expiresAt: Date?
}
