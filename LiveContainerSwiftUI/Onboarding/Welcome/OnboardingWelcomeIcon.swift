//
//  OnboardingWelcomeIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's icon on the welcome screen, which puts itself together: the
/// near black tile swells in, the pink container draws itself around it, and
/// the z pops into the middle with a light tap. With Reduce Motion the icon
/// only fades in, and with VoiceOver it's there from the start.
struct OnboardingWelcomeIcon: View {
    let isRevealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var stage = ZContainerMarkStage.hidden

    var body: some View {
        ZContainerMark(stage: stage)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: stage) { _, newStage in
                newStage == .letter
            }
            .onChange(of: isRevealed, initial: true, arrive)
    }

    /// Brings the icon in, one part after another, the first time the
    /// screen shows.
    private func arrive() {
        guard isRevealed, stage == .hidden else { return }
        if voiceOverEnabled {
            stage = .letter
        } else if reduceMotion {
            // ZContainerMark keeps its parts whole with Reduce Motion, so
            // only their opacity changes.
            withAnimation(OnboardingDesign.markFade) {
                stage = .letter
            }
        } else {
            withAnimation(OnboardingDesign.markTileArrival) {
                stage = .tile
            } completion: {
                withAnimation(OnboardingDesign.markFrameDrawing) {
                    stage = .frame
                } completion: {
                    withAnimation(OnboardingDesign.markLetterArrival) {
                        stage = .letter
                    }
                }
            }
        }
    }
}
