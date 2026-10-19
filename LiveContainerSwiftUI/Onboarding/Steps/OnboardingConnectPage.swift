//
//  OnboardingConnectPage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The step that ties zContainer to Zeus, ticked off on a checklist: Zeus is
/// installed, the certificate Zeus put inside zContainer is stored, and it
/// belongs to the team that signed zContainer. Installed from Zeus's official
/// source, all three are ticked on arrival, and Continue is pinned at the
/// bottom. Otherwise the step says what's in the way and how to get past it,
/// with Open Zeus, the import of a certificate of one's own, and Set Up
/// Later.
///
/// The certificate is what signing takes, so Continue shows once it's usable
/// and of zContainer's own team, even without Zeus on this iPhone, as for
/// someone who signed zContainer another way and imported its .p12. The Zeus
/// row then only says that Zeus isn't there.
///
/// The checklist is read again whenever zContainer comes back to the front,
/// like after a visit to Zeus.
struct OnboardingConnectPage: View {
    @Environment(ZeusConnection.self) private var connection
    @Environment(OnboardingFlow.self) private var flow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        OnboardingSetupForm {
            OnboardingHeader(systemImage: "bolt.fill", title: "zc.onboarding.connect.title".loc, message: message)
        } content: {
            Section {
                OnboardingChecklistRow(systemImage: "bolt.fill", title: "zc.settings.zeus".loc, isDone: connection.isZeusInstalled) {
                    Text(zeusDetail)
                }

                OnboardingChecklistRow(systemImage: "checkmark.seal.fill", title: "zc.settings.zeus.certificate".loc, isDone: connection.isCertificateUsable) {
                    Text(certificateDetail)
                }

                OnboardingChecklistRow(systemImage: "person.2.fill", title: "zc.onboarding.connect.sameTeam".loc, isDone: connection.isSameTeam == true) {
                    Text(teamDetail)
                }
            } footer: {
                Text("zc.onboarding.connect.footer".loc)
            }
        }
        .onboardingBottomBar {
            OnboardingFooter {
                if connection.isReadyToSign {
                    OnboardingPrimaryButton(title: "lc.common.continue".loc, action: continueTapped)
                } else {
                    OnboardingOpenZeusButton(isPrimary: true)

                    ZeusImportCertificateButton(title: "zc.onboarding.connect.import".loc)
                        .buttonStyle(OnboardingPlainButtonStyle())

                    OnboardingSecondaryButton(title: "zc.onboarding.setUpLater".loc, action: skip)
                }
            }
        }
        .animation(reduceMotion ? nil : OnboardingDesign.spring, value: connection.isReadyToSign)
        // A tap for getting ready, not for losing it.
        .sensoryFeedback(.success, trigger: connection.isReadyToSign) { _, isReady in
            isReady
        }
        .onChange(of: scenePhase, initial: true, refresh)
        // Apple tells whether the certificate was revoked, and when an
        // imported one expires.
        .task(id: connection.certificateVersion) {
            await connection.checkCertificateIfNeeded()
        }
    }

    /// What the step says under its title: that zContainer is ready, or
    /// what's in the way, so someone who installed zContainer from Zeus
    /// isn't told to do it again.
    private var message: String {
        if connection.isReadyToSign {
            connection.isZeusInstalled
                ? "zc.onboarding.connect.connected".loc
                : "zc.onboarding.connect.readyWithoutZeus".deviceLoc
        } else if connection.validity == .revoked {
            "zc.settings.zeus.revokedNotice".loc
        } else if connection.isExpired {
            "zc.settings.zeus.expiredNotice".loc
        } else if connection.problem != nil || connection.isSameTeam == false {
            "zc.onboarding.connect.problem".loc
        } else if connection.hasCertificate {
            "zc.onboarding.connect.checking".loc
        } else {
            "zc.onboarding.connect.notConnected".loc
        }
    }

    private var zeusDetail: String {
        connection.isZeusInstalled
            ? "zc.onboarding.connect.zeusInstalled".deviceLoc
            : "zc.onboarding.connect.zeusMissing".deviceLoc
    }

    /// The certificate's team and expiry, or what's wrong with it.
    private var certificateDetail: String {
        if let problem = connection.problem {
            problem
        } else if connection.validity == .revoked {
            "zc.settings.attention.revoked".loc
        } else if connection.hasCertificate {
            connection.summary
        } else {
            "zc.settings.zeus.noCertificate".loc
        }
    }

    private var teamDetail: String {
        let unknown = "lc.common.unknown".loc
        switch connection.isSameTeam {
        case true?:
            return "zc.onboarding.connect.sameTeamMatch %@".localizeWithFormat(connection.teamID ?? unknown)
        case false?:
            let certificateTeam = connection.mismatchedTeamID ?? connection.teamID ?? unknown
            return "zc.onboarding.connect.sameTeamMismatch %@ %@".localizeWithFormat(certificateTeam, connection.ownTeamID ?? unknown)
        case nil:
            return connection.hasCertificate
                ? "zc.onboarding.connect.sameTeamReading".loc
                : "zc.onboarding.connect.sameTeamUnknown".loc
        }
    }

    /// Reads the checklist again when zContainer comes to the front.
    private func refresh() {
        guard scenePhase == .active else { return }
        connection.reload()
    }

    private func continueTapped() {
        flow.advance(from: .connect)
    }

    private func skip() {
        flow.skip(.connect, hasCertificate: connection.hasCertificate)
    }
}
