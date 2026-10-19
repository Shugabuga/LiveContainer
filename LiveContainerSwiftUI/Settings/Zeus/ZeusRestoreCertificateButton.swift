//
//  ZeusRestoreCertificateButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Puts back the certificate Zeus put inside zContainer, in place of one
/// imported by hand or after one was removed, and checks it as the launch
/// does. A problem the check finds shows at the top of the Zeus page, since
/// this button goes away once Zeus's certificate is back.
struct ZeusRestoreCertificateButton: View {
    @Environment(ZeusConnection.self) private var connection
    @State private var isRestoring = false

    var body: some View {
        Button("lc.settings.useZeusCertificate".loc, action: restore)
            .disabled(isRestoring)
    }

    private func restore() {
        isRestoring = true
        Task {
            await connection.useZeusCertificate()
            isRestoring = false
        }
    }
}
