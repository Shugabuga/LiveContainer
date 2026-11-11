//
//  HomeRouter+Certificates.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What happens to a certificate sent to zContainer: Zeus's, which Zeus leaves
/// in the app group the two apps share, one sent as a certificate link, or a
/// .p12 file opened with zContainer. A file's password is asked for, then the
/// person is asked whether zContainer should sign apps with it, and once it's
/// stored, it's checked the way Check Setup checks it. A certificate of
/// another team than the one that signed zContainer is turned down, since the
/// apps it signed wouldn't open. For Zeus's certificate, how it ended is
/// written back to the group for Zeus. CertificateImportPresentation shows
/// the questions; what goes wrong shows through `launchProblem`.
extension HomeRouter {
    /// Asks whether to use the certificate a link sent, once ZSign opens it.
    func review(_ certificate: CertificateLink) async {
        guard acceptsCertificates() else {
            return
        }
        guard let teamID = await ZeusCertificateImport.teamID(of: certificate.certificateData, password: certificate.password) else {
            launchProblem = "lc.settings.invalidCertError".loc
            return
        }
        askToUse(certificate, teamID: teamID, source: .link)
    }

    /// Reads a .p12 file zContainer was asked to open, then asks for its
    /// password. A copy iOS left in the Inbox is deleted once read, so the
    /// private key doesn't stay behind there.
    func openCertificateFile(_ url: URL) {
        guard acceptsCertificates() else {
            return
        }
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url)
            let inbox = URL.documentsDirectory.appendingPathComponent("Inbox")
            if url.deletingLastPathComponent().standardizedFileURL == inbox.standardizedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            lockedCertificate = LockedCertificate(data: data, isRetry: false)
        } catch {
            launchProblem = "zc.certificateImport.unreadable".loc
        }
    }

    /// Opens a .p12 file with the password typed for it and asks whether to
    /// use it, or asks for the password again when it doesn't open.
    func unlock(_ locked: LockedCertificate, password: String) async {
        let certificate = CertificateLink(certificateData: locked.data, password: password)
        guard let teamID = await ZeusCertificateImport.teamID(of: locked.data, password: password) else {
            lockedCertificate = LockedCertificate(data: locked.data, isRetry: true)
            return
        }
        askToUse(certificate, teamID: teamID, source: .file)
    }

    /// Stores the certificate the person said to use, then checks that it
    /// signs, as Check Setup does, and says it's ready or what went wrong.
    /// While onboarding shows, its own steps check it and say so instead.
    /// Zeus's certificate is stored as Zeus's own, and Zeus hears it was
    /// taken.
    func use(_ offer: CertificateOffer) async {
        let certificate = offer.certificate
        switch offer.source {
        case .link, .file:
            ZeusCertificateImport.store(certificate.certificateData, password: certificate.password)
        case let .zeus(requestID, serialNumber, expiresAt):
            ZeusCertificateImport.storeFromZeus(
                certificate.certificateData,
                password: certificate.password,
                teamID: offer.teamID,
                serialNumber: serialNumber,
                expiresAt: expiresAt
            )
            ZeusGroup.writeResult(ZeusRequestResult(id: requestID, outcome: .accepted))
        }
        certificatesStored += 1
        guard !onboarding.isPresented else {
            return
        }
        let (passed, error) = await ZeusCertificate.validateJITLessSetup()
        ZeusCertificate.lastCheckPassed = passed
        guard passed else {
            var reason = "lc.jitlessSetup.error.testLibLoadFailed".loc
            if let error {
                reason += "\n" + error.localizedDescription.loc
            }
            launchProblem = reason
            return
        }
        storedCertificateTeam = offer.teamID
    }

    /// Keeps the certificate zContainer has, as the person chose, and closes
    /// the question. For Zeus's certificate, Zeus hears it wasn't taken.
    func decline(_ offer: CertificateOffer) {
        if case .zeus(let requestID, _, _) = offer.source {
            ZeusGroup.writeResult(ZeusRequestResult(id: requestID, outcome: .declined))
        }
        if certificateOffer == offer {
            certificateOffer = nil
        }
    }

    /// Whether this zContainer takes certificates. A second zContainer signs
    /// with the first one's certificate, so it says where to import instead.
    private func acceptsCertificates() -> Bool {
        guard sharedModel.multiLCStatus != 2 else {
            launchProblem = "zc.certificateImport.secondary".loc
            return false
        }
        return true
    }

    /// Asks whether to use a certificate ZSign opened, when it belongs to the
    /// team that signed zContainer, or to a team zContainer can't tell. A
    /// question still open about another certificate is answered as declined,
    /// since only one shows at a time.
    func askToUse(_ certificate: CertificateLink, teamID: String, source: CertificateSource) {
        if let ownTeamID = LCSharedUtils.teamIdentifier(), ownTeamID != teamID {
            let problem = "zc.certificateImport.otherTeam %@ %@".localizeWithFormat(teamID, ownTeamID)
            if case .zeus(let requestID, _, _) = source {
                ZeusGroup.writeResult(ZeusRequestResult(id: requestID, outcome: .failed, failure: .otherTeam, message: problem))
            }
            launchProblem = problem
            return
        }
        if let openOffer = certificateOffer {
            decline(openOffer)
        }
        certificateOffer = CertificateOffer(
            certificate: certificate,
            teamID: teamID,
            replacesCurrent: LCSharedUtils.certificatePassword() != nil,
            source: source
        )
    }
}
