//
//  ZeusMissingAlert.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What Open Zeus says when Zeus isn't on this iPhone, with a button that
/// opens Zeus's website to get it.
struct ZeusMissingAlert: ViewModifier {
    @Binding var isPresented: Bool

    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .alert("zc.settings.zeus.zeusMissing".loc, isPresented: $isPresented) {
                Button("zc.settings.zeus.getZeus".loc, action: getZeus)
                Button("lc.common.cancel".loc, role: .cancel) { }
            }
    }

    private func getZeus() {
        guard let url = ZeusConnection.websiteURL else {
            return
        }
        openURL(url)
    }
}

extension View {
    /// Says Zeus isn't on this iPhone while `isPresented` is true, offering
    /// Zeus's website.
    func zeusMissingAlert(isPresented: Binding<Bool>) -> some View {
        modifier(ZeusMissingAlert(isPresented: isPresented))
    }
}
