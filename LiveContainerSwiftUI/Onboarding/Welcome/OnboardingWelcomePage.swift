//
//  OnboardingWelcomePage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The first screen, laid out like the welcome screens of Apple's own apps:
/// zContainer's icon and name, what it does, and Continue pinned at the
/// bottom under a note on what sharing one sandbox means.
struct OnboardingWelcomePage: View {
    @Environment(OnboardingFlow.self) private var flow

    /// Set the first time the screen appears, which starts the header and the
    /// features arriving in turn. Coming back with Back leaves them in place.
    @State private var isRevealed = false

    var body: some View {
        ScrollView {
            VStack(spacing: OnboardingDesign.welcomeSpacing) {
                OnboardingWelcomeHeader(isRevealed: isRevealed)

                VStack(alignment: .leading, spacing: OnboardingDesign.featureSpacing) {
                    ForEach(OnboardingFeature.allCases) { feature in
                        OnboardingFeatureRow(feature: feature)
                            .onboardingReveal(isRevealed, order: feature.rawValue + 1)
                    }
                }
            }
            .padding(.horizontal, OnboardingDesign.welcomeMargin)
            .padding(.top, OnboardingDesign.welcomeTopPadding)
            .padding(.bottom, OnboardingDesign.welcomeBottomPadding)
            .frame(maxWidth: OnboardingDesign.contentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(OnboardingDesign.background)
        .navigationBarTitleDisplayMode(.inline)
        .onboardingBottomBar {
            OnboardingFooter {
                OnboardingSandboxNote()
                OnboardingPrimaryButton(title: "lc.common.continue".loc, action: continueTapped)
            }
            // The footer arrives after the features.
            .onboardingReveal(isRevealed, order: OnboardingFeature.allCases.count + 1)
        }
        .onAppear(perform: reveal)
    }

    private func reveal() {
        isRevealed = true
    }

    private func continueTapped() {
        flow.begin()
    }
}
