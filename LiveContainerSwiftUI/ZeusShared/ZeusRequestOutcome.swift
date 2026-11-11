//
//  ZeusRequestOutcome.swift
//  LiveContainerSwiftUI
//

import Foundation

/// How zContainer answered a request from Zeus.
enum ZeusRequestOutcome: String, Encodable, Sendable {
    /// The app was installed as a new app.
    case added
    /// The app replaced the copy zContainer held, keeping its data.
    case replaced
    /// The person cancelled.
    case cancelled
    /// The request couldn't be carried out (see ZeusRequestFailure).
    case failed
    /// The person chose to use Zeus's certificate.
    case accepted
    /// The person chose to keep the certificate zContainer had.
    case declined
}
