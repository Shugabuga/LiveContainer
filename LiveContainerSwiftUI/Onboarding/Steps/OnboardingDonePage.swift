//
//  OnboardingDonePage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The last step: zContainer is ready, with what was set up ticked off and
/// anything left for later waiting in Settings. Like the last page of iOS's
/// own setup, it only goes forward, and its button fades the Home Screen in.
struct OnboardingDonePage: View {
    @Environment(OnboardingModel.self) private var onboarding
    @Environment(ZeusConnection.self) private var connection
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        OnboardingSetupForm {
            OnboardingHeader(title: "zc.onboarding.done.title".loc, message: message) {
                OnboardingDoneSymbol()
            }
        } content: {
            Section {
                OnboardingChecklistRow(systemImage: "bolt.fill", title: "zc.settings.zeus".loc, isDone: connection.isConnected) {
                    Text(connection.isConnected ? "zc.onboarding.done.connected".loc : "zc.onboarding.done.notSetUp".loc)
                }

                OnboardingChecklistRow(systemImage: "signature", title: "zc.settings.setup.signing".loc, isDone: isSigningChecked) {
                    Text(isSigningChecked ? "zc.onboarding.done.checked".loc : "zc.onboarding.done.notSetUp".loc)
                }

                OnboardingChecklistRow(systemImage: "square.grid.2x2.fill", title: "zc.onboarding.done.apps".loc, isDone: !installedNames.isEmpty) {
                    Text(appsDetail)
                }
            }
        }
        .onboardingBottomBar {
            OnboardingFooter {
                OnboardingPrimaryButton(title: "zc.onboarding.done.start".loc, action: finish)
            }
        }
        .navigationBarBackButtonHidden()
    }

    /// Whether signing passed Check Setup.
    private var isSigningChecked: Bool {
        connection.result(for: .signing) == .passed
    }

    private var installedNames: [String] {
        onboarding.pendingInstalls.installedNames
    }

    private var message: String {
        connection.isConnected && isSigningChecked
            ? "zc.onboarding.done.ready".loc
            : "zc.onboarding.done.later".loc
    }

    /// The apps that came in, or that some are still coming.
    private var appsDetail: String {
        if !installedNames.isEmpty {
            installedNames.formatted()
        } else if onboarding.pendingInstalls.hasUnfinishedItems {
            "zc.home.installing".loc
        } else {
            "zc.onboarding.done.noApps".loc
        }
    }

    private func finish() {
        flow.advance(from: .done)
    }
}
