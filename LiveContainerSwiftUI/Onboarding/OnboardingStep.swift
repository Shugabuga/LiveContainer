//
//  OnboardingStep.swift
//  LiveContainerSwiftUI
//

/// The steps of onboarding pushed over the welcome screen, in the order they come.
enum OnboardingStep: Hashable {
    /// Zeus is installed, and zContainer holds a certificate of its own team.
    case connect

    /// Signing a test library the way apps are signed, and the parts Zeus
    /// sets up when it signs zContainer.
    case checkSetup

    /// The apps Zeus sent, installing, and ways to add more.
    case addApps

    /// Where everything stands, and the way to the Home Screen.
    case done

    /// The step after this one, or nil after the last.
    var next: OnboardingStep? {
        switch self {
        case .connect: .checkSetup
        case .checkSetup: .addApps
        case .addApps: .done
        case .done: nil
        }
    }

    /// The step after this one once it's left for later. Without a
    /// certificate, Check Setup has nothing to check, so leaving Connect to
    /// Zeus for later passes over it.
    func nextWhenSkipped(hasCertificate: Bool) -> OnboardingStep? {
        self == .connect && !hasCertificate ? .addApps : next
    }
}
