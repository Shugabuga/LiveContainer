//
//  CertificateSource.swift
//  LiveContainerSwiftUI
//

import Foundation

/// How a certificate reached zContainer, which decides how it is stored once
/// the person says to use it, and whether Zeus hears how the question ended.
enum CertificateSource: Equatable {
    /// A `certificate?cert=&password=` link, which any app can open.
    case link
    /// A .p12 (or .pfx) file opened with zContainer, once its password was
    /// typed.
    case file
    /// Zeus's certificate, which Zeus left in the app group the two apps
    /// share. It is stored as Zeus's own certificate, and the request it came
    /// with gets a result.
    /// - Parameters:
    ///   - requestID: The request Zeus wrote it with.
    ///   - serialNumber: The certificate's serial number, in hexadecimal.
    ///   - expiresAt: When the certificate expires, when Zeus said.
    case zeus(requestID: UUID, serialNumber: String, expiresAt: Date?)
}
