//
//  CertificateLink.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A signing certificate sent to zContainer as a link,
/// `zcontainer://certificate?cert=<Base64 .p12>&password=<password>`, the way
/// Zeus answers when zContainer asks it for one.
struct CertificateLink: Equatable {
    /// The certificate and its private key, as a .p12.
    let certificateData: Data
    /// The password that opens the .p12.
    let password: String

    /// Reads the certificate from a `certificate` link. Returns nil when the
    /// link lacks the certificate or its password, or the certificate isn't
    /// valid Base64. Query item names are read without regard to case.
    init?(url: URL) {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var values: [String: String] = [:]
        for item in queryItems {
            values[item.name.lowercased()] = item.value
        }
        guard let encoded = values["cert"]?.removingPercentEncoding,
              let password = values["password"],
              let certificateData = Data(base64Encoded: encoded) else {
            return nil
        }
        self.certificateData = certificateData
        self.password = password
    }
}
