//
//  OnboardingOpenZeusButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Opens Zeus, where zContainer gets installed, signed again, or sent apps:
/// as a page's main button, or a plain one under it. When Zeus isn't on this
/// iPhone, it says so, and offers Zeus's website.
struct OnboardingOpenZeusButton: View {
    /// Whether it's the page's main button.
    let isPrimary: Bool

    @Environment(\.openURL) private var openURL
    @State private var isZeusMissing = false

    var body: some View {
        Group {
            if isPrimary {
                OnboardingPrimaryButton(title: "zc.settings.zeus.openZeus".loc, action: openZeus)
            } else {
                OnboardingSecondaryButton(title: "zc.settings.zeus.openZeus".loc, action: openZeus)
            }
        }
        .zeusMissingAlert(isPresented: $isZeusMissing)
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
