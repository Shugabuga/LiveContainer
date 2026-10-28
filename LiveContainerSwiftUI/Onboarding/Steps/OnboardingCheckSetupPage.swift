//
//  OnboardingCheckSetupPage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The step that makes sure zContainer can sign apps, in place of the
/// patching other sideloaders ask for: as it shows, it signs a test library
/// with the certificate, the way apps are signed, and checks that iOS loads
/// it, beside the optional parts Zeus sets up. Continue is pinned at the
/// bottom once signing works. When it doesn't, the step says why, Open Zeus
/// gets zContainer signed again, Check Again checks once more, and the
/// diagnosis shows the details.
struct OnboardingCheckSetupPage: View {
    @Environment(ZeusConnection.self) private var connection
    @Environment(OnboardingFlow.self) private var flow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isShowingDiagnosis = false

    var body: some View {
        OnboardingSetupForm {
            OnboardingHeader(systemImage: "checkmark.shield.fill", title: "zc.settings.setup.check".loc, message: message)
        } content: {
            Section {
                ForEach(ZeusSetupCheck.allCases, id: \.self) { check in
                    OnboardingSetupCheckRow(check: check, result: connection.result(for: check))
                }
            } footer: {
                Text("zc.onboarding.check.footer".loc)
            }

            if hasFailed {
                Section {
                    Button("lc.settings.jitlessDiagnose".loc, action: showDiagnosis)
                }
            }
        }
        .onboardingBottomBar {
            OnboardingFooter {
                if hasFailed {
                    OnboardingOpenZeusButton(isPrimary: true)
                    OnboardingSecondaryButton(title: "zc.onboarding.check.retry".loc, action: checkAgain)
                    OnboardingSecondaryButton(title: "zc.onboarding.setUpLater".loc, action: skip)
                } else {
                    OnboardingProgressButton(
                        title: "lc.common.continue".loc,
                        progressTitle: "zc.settings.setup.checking".loc,
                        isInProgress: !hasPassed,
                        action: continueTapped
                    )
                }
            }
        }
        .animation(reduceMotion ? nil : OnboardingDesign.spring, value: signing)
        .sensoryFeedback(.success, trigger: hasPassed) { _, hasPassed in
            hasPassed
        }
        .sensoryFeedback(.error, trigger: hasFailed) { _, hasFailed in
            hasFailed
        }
        .sheet(isPresented: $isShowingDiagnosis) {
            OnboardingDiagnosisSheet()
        }
        // A certificate stored while the step shows, like the one Zeus
        // sends, starts over with nothing known about it, so it's checked
        // as it arrives.
        .task(id: connection.certificateVersion) {
            await checkIfNeeded()
        }
    }

    /// How signing stands, which decides the step.
    private var signing: ZeusCheckResult {
        connection.result(for: .signing)
    }

    private var hasPassed: Bool {
        signing == .passed
    }

    private var hasFailed: Bool {
        signing.failure != nil
    }

    private var message: String {
        if hasPassed {
            "zc.onboarding.check.passed".loc
        } else if hasFailed {
            "zc.onboarding.check.failed".loc
        } else {
            "zc.onboarding.check.checking".loc
        }
    }

    /// Checks the setup as the step shows, and again for each different
    /// certificate stored while it does, unless it already passed, like when
    /// coming back to the step.
    private func checkIfNeeded() async {
        guard !hasPassed else { return }
        await connection.checkSetup()
    }

    private func checkAgain() {
        Task {
            await connection.checkSetup()
        }
    }

    private func showDiagnosis() {
        isShowingDiagnosis = true
    }

    private func continueTapped() {
        flow.advance(from: .checkSetup)
    }

    private func skip() {
        flow.skip(.checkSetup, hasCertificate: connection.hasCertificate)
    }
}
