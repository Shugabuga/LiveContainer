//
//  OnboardingView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The first launch, laid out like Zeus's own and Apple's: a welcome to
/// zContainer, then a page for each thing that makes zContainer and Zeus
/// work together, pushed one after another, so Back is the system's own
/// button and swipe. Every step can wait until later. Finishing hands back to
/// OnboardingModel, which fades the Home Screen in.
struct OnboardingView: View {
    @Environment(OnboardingModel.self) private var onboarding
    @Environment(HomeRouter.self) private var router

    @State private var flow: OnboardingFlow
    /// The certificate and setup state the steps share, read afresh each
    /// time onboarding opens.
    @State private var connection = ZeusConnection()

    /// - Parameter startsAtConnect: Whether to open on Connect to Zeus, with
    ///   the welcome screen a step back, as Settings asks for.
    init(startsAtConnect: Bool) {
        _flow = State(initialValue: OnboardingFlow(startingAt: startsAtConnect ? .connect : nil))
    }

    var body: some View {
        NavigationStack(path: $flow.path) {
            OnboardingWelcomePage()
                .navigationDestination(for: OnboardingStep.self, destination: OnboardingDestination.init)
        }
        .environment(flow)
        .environment(connection)
        // zContainer's pink, as Zeus's onboarding has Zeus's.
        .tint(OnboardingDesign.accent)
        .onChange(of: flow.isFinished, finish)
        // A certificate Zeus sent, or a .p12 opened with zContainer, was
        // stored over onboarding.
        .onChange(of: router.certificatesStored) {
            connection.certificateChanged()
        }
    }

    private func finish() {
        guard flow.isFinished else { return }
        onboarding.finish()
    }
}
