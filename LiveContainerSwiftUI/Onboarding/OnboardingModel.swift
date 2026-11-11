//
//  OnboardingModel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Whether onboarding shows over the Home Screen, and the apps sent to
/// zContainer meanwhile.
///
/// Onboarding shows on the first launch, unless a certificate is stored and
/// the last check of the setup passed, as when zContainer was set up before.
/// Once it's finished, even with steps left for later, it stays away;
/// Settings' "Finish Setting Up zContainer" row opens it again. While it
/// shows, install links wait in `pendingInstalls`, so none is lost, even
/// when zContainer closes before they're installed. Install links that
/// arrive while another app installs wait there too, as do the apps Zeus
/// leaves in the app group the two apps share.
@MainActor
@Observable
final class OnboardingModel {
    /// Where finishing onboarding is remembered.
    private static let completedKey = "ZCHasCompletedOnboarding"

    /// Whether onboarding shows over the Home Screen.
    private(set) var isPresented: Bool
    /// Whether onboarding still covers the Home Screen: from when it opens
    /// until it has faded away. The window keeps onboarding's appearance
    /// until then, rather than the Home Screen's black one.
    private(set) var coversHomeScreen: Bool
    /// Whether onboarding opens on Connect to Zeus, with the welcome screen a
    /// step back, as it does when Settings opens it.
    private(set) var startsAtConnect = false

    /// The apps on their way in: those sent while onboarding shows or while
    /// another app installs, and the apps Zeus leaves in the app group.
    let pendingInstalls: PendingInstallQueue

    init(coordinator: AppLaunchCoordinator) {
        let isNeeded = Self.isNeededAtLaunch(sharedModel: coordinator.sharedModel)
        pendingInstalls = PendingInstallQueue(coordinator: coordinator, holdsForOnboarding: isNeeded)
        isPresented = isNeeded
        coversHomeScreen = isNeeded
    }

    /// Whether onboarding shows when zContainer opens: on the first launch,
    /// unless a certificate is stored and the last check of the setup
    /// passed. A second zContainer signs with the first one's certificate
    /// and installs nothing itself, so it never shows there.
    private static func isNeededAtLaunch(sharedModel: SharedModel) -> Bool {
        guard sharedModel.multiLCStatus != 2,
              !UserDefaults.standard.bool(forKey: completedKey) else {
            return false
        }
        let hasCertificate = LCSharedUtils.certificatePassword() != nil
        return !(hasCertificate && ZeusCertificate.lastCheckPassed == true)
    }

    /// Opens onboarding again on Connect to Zeus, as Settings' "Finish
    /// Setting Up zContainer" row does. The root view closes what's open over
    /// the Home Screen first.
    func present() {
        guard !isPresented else { return }
        startsAtConnect = true
        coversHomeScreen = true
        pendingInstalls.holdForOnboarding()
        withAnimation(OnboardingDesign.coverFade) {
            isPresented = true
        }
    }

    /// Remembers that onboarding is done, so it doesn't come back, and fades
    /// it away over the Home Screen. Apps still on their way in carry on.
    func finish() {
        guard isPresented else { return }
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        pendingInstalls.onboardingDidClose()
        withAnimation(OnboardingDesign.homeArrival) {
            isPresented = false
        } completion: {
            self.coversHomeScreen = false
        }
    }

    /// Takes an install link while onboarding shows, while apps it took are
    /// still coming in, or while another app installs, so the link waits its
    /// turn rather than being turned away by the install that's running.
    /// Returns false for any other link, and whenever AppLaunchCoordinator
    /// should handle the link as usual.
    /// - Parameters:
    ///   - link: An app link zContainer was opened with.
    ///   - whileInstalling: Whether AppLaunchCoordinator is installing an
    ///     app, which onboarding can't see for itself.
    func takeLink(_ link: AppLink, whileInstalling: Bool) -> Bool {
        guard case .install(let address) = link,
              isPresented || pendingInstalls.hasUnfinishedItems || whileInstalling else {
            return false
        }
        return pendingInstalls.receive(address: address)
    }
}
