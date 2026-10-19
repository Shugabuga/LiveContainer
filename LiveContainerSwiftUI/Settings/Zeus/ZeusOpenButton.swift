//
//  ZeusOpenButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Opens Zeus, where zContainer gets signed again with a fresh certificate.
/// When Zeus isn't on this iPhone, it says so.
struct ZeusOpenButton: View {
    @Environment(\.openURL) private var openURL
    @State private var isZeusMissing = false

    var body: some View {
        Button("zc.settings.zeus.openZeus".loc, action: openZeus)
            .alert("zc.settings.zeus.zeusMissing".loc, isPresented: $isZeusMissing) { }
    }

    private func openZeus() {
        guard let url = ZeusConnection.zeusURL else {
            return
        }
        openURL(url) { accepted in
            isZeusMissing = !accepted
        }
    }
}
