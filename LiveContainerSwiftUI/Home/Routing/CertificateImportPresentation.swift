//
//  CertificateImportPresentation.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Shows the questions a certificate sent to zContainer asks, over the main
/// window's root: the password of a .p12 file opened with zContainer, whether
/// zContainer should sign apps with the certificate, and that it's ready once
/// stored and checked. HomeRouter decides which one shows.
struct CertificateImportPresentation: ViewModifier {
    let router: HomeRouter

    /// The password typed for a .p12 file.
    @State private var password = ""

    func body(content: Content) -> some View {
        @Bindable var router = router

        content
            .alert(
                "zc.settings.zeus.passwordTitle".loc,
                isPresented: Binding<Bool>.isPresented(for: $router.lockedCertificate),
                presenting: router.lockedCertificate
            ) { locked in
                SecureField("zc.settings.zeus.password".loc, text: $password)
                Button("lc.common.continue".loc) {
                    unlock(locked)
                }
                Button("lc.common.cancel".loc, role: .cancel, action: forgetPassword)
            } message: { locked in
                Text(locked.isRetry ? "zc.certificateImport.wrongPassword".loc : "zc.settings.zeus.passwordMessage".loc)
            }
            .alert(
                "zc.certificateImport.title".loc,
                isPresented: Binding<Bool>.isPresented(for: $router.certificateOffer),
                presenting: router.certificateOffer
            ) { offer in
                Button("zc.certificateImport.use".loc) {
                    use(offer)
                }
                Button("lc.common.cancel".loc, role: .cancel) {
                    decline(offer)
                }
            } message: { offer in
                Text(message(for: offer))
            }
            .alert(
                "zc.certificateImport.readyTitle".loc,
                isPresented: Binding<Bool>.isPresented(for: $router.storedCertificateTeam),
                presenting: router.storedCertificateTeam
            ) { _ in
                Button("lc.common.ok".loc) { }
            } message: { teamID in
                Text("zc.certificateImport.readyMessage %@".localizeWithFormat(teamID))
            }
    }

    /// What the question says: the certificate's team, and that it takes the
    /// place of the certificate zContainer has, when it has one.
    private func message(for offer: CertificateOffer) -> String {
        let key = offer.replacesCurrent ? "zc.certificateImport.replaceMessage %@" : "zc.certificateImport.message %@"
        return key.localizeWithFormat(offer.teamID)
    }

    private func unlock(_ locked: LockedCertificate) {
        let password = password
        forgetPassword()
        Task {
            await router.unlock(locked, password: password)
        }
    }

    private func use(_ offer: CertificateOffer) {
        Task {
            await router.use(offer)
        }
    }

    private func decline(_ offer: CertificateOffer) {
        router.decline(offer)
    }

    private func forgetPassword() {
        password = ""
    }
}

extension View {
    /// Shows the questions a certificate sent to zContainer asks. Apply it
    /// once, on the main window's root.
    func certificateImportPresentation(_ router: HomeRouter) -> some View {
        modifier(CertificateImportPresentation(router: router))
    }
}
