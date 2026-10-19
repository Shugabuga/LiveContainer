//
//  OnboardingIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A small icon in the style of Zeus's onboarding: a squircle outline in
/// zContainer's pink, with a faint fill of it and a symbol inside. Once its
/// step is done it fills in solid, and the symbol gives way to a white check.
struct OnboardingIcon: View {
    /// The SF Symbol inside, until the step is done.
    let systemImage: String
    var isDone = false

    @ScaledMetric(relativeTo: .headline) private var size = OnboardingDesign.iconSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * OnboardingDesign.iconCornerRatio)

        Image(systemName: isDone ? "checkmark" : systemImage)
            .resizable()
            .scaledToFit()
            .bold(isDone)
            .foregroundStyle(isDone ? Color.white : OnboardingDesign.accent)
            .frame(width: size * OnboardingDesign.glyphRatio, height: size * OnboardingDesign.glyphRatio)
            // A new symbol is a new view, so it can scale in over the old one.
            .id(isDone)
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            .frame(width: size, height: size)
            .background(OnboardingDesign.accent.opacity(isDone ? 1 : OnboardingDesign.iconFillOpacity), in: shape)
            .overlay {
                shape.strokeBorder(OnboardingDesign.accent, lineWidth: size * OnboardingDesign.iconStrokeRatio)
            }
            .animation(OnboardingDesign.spring, value: isDone)
            .accessibilityHidden(true)
    }
}
