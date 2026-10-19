//
//  ZeusCertificateSource.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where the certificate zContainer signs apps with came from.
enum ZeusCertificateSource: Equatable {
    /// No certificate is stored, so zContainer can't sign apps.
    case none
    /// Zeus put it inside zContainer when it signed it.
    case zeus
    /// The person imported a .p12 of their own.
    case imported
}
