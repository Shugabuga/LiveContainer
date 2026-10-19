//
//  ZeusRemoveCertificateButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Removes the stored certificate, after asking, so zContainer stops signing
/// apps until it has one again.
struct ZeusRemoveCertificateButton: View {
    @Environment(ZeusConnection.self) private var connection
    @State private var isConfirming = false

    var body: some View {
        Button("lc.settings.removeCertificate".loc, role: .destructive, action: confirm)
            .confirmationDialog("zc.settings.zeus.removeTitle".loc, isPresented: $isConfirming, titleVisibility: .visible) {
                Button("lc.common.remove".loc, role: .destructive, action: remove)
            } message: {
                Text("zc.settings.zeus.removeMessage".loc)
            }
    }

    private func confirm() {
        isConfirming = true
    }

    private func remove() {
        connection.removeCertificate()
    }
}
