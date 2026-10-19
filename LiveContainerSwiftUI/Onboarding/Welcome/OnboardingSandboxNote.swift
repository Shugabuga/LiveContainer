//
//  OnboardingSandboxNote.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The note above Continue on the welcome screen, where Apple's own welcome
/// screens note privacy: the apps inside zContainer share one sandbox, so
/// they can see each other's files and use zContainer's certificate.
struct OnboardingSandboxNote: View {
    var body: some View {
        Text("zc.onboarding.sandboxNote".loc)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.bottom, OnboardingDesign.noteSpacing)
    }
}
