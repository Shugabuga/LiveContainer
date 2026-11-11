//
//  CertificateLink.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A signing certificate sent to zContainer: as a link,
/// `zcontainer://certificate?cert=<Base64 .p12>&password=<password>`, as a
/// .p12 opened with zContainer once its password is typed, or as the one Zeus
/// leaves in the app group the two apps share. The link is read the same on
/// zContainer's own scheme and on the one Zeus adds when it signs zContainer
/// (`zeus-` and the bundle ID). Any app can declare either scheme, so another
/// app may get a link meant for zContainer. Zeus no longer sends its
/// certificate as a link: it leaves it in the app group, or exports it as a
/// .p12 when the two apps share none.
struct CertificateLink: Equatable {
    /// The certificate and its private key, as a .p12.
    let certificateData: Data
    /// The password that opens the .p12.
    let password: String

    init(certificateData: Data, password: String) {
        self.certificateData = certificateData
        self.password = password
    }

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
