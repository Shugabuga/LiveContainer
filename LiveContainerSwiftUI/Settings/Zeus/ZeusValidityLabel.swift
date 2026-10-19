//
//  ZeusValidityLabel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What Apple said about the certificate, on the trailing side of its Status
/// row: a spinner while asking, then Valid, Revoked, or that it couldn't be
/// asked. Each answer has its own symbol as well as its color.
struct ZeusValidityLabel: View {
    let validity: ZeusCertificateValidity

    var body: some View {
        switch validity {
        case .unknown:
            Text("zc.settings.setup.notChecked".loc)
        case .checking:
            ProgressView()
                .accessibilityLabel("lc.jitlessDiag.checking".loc)
        case .valid:
            Label("lc.jitlessDiag.certificateValid".loc, systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .revoked:
            Label("lc.jitlessDiag.certificateRevoked".loc, systemImage: "xmark.seal.fill")
                .foregroundStyle(.red)
        case .unavailable:
            Label("zc.settings.zeus.couldNotCheck".loc, systemImage: "questionmark.circle")
        }
    }
}
