//
//  HomeRouter+ZeusRequests.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What zContainer does with the requests Zeus leaves in the app group the
/// two apps share (see ZeusGroup). A `zeus-request` link from Zeus names
/// them. When a guest app gets the link instead, it says to go back to
/// zContainer's Home Screen, and a rescan finds the requests as the window
/// comes to the front.
///
/// Each request is taken once, whichever way it is found: an app joins
/// onboarding's queue, which copies it out of the group, installs it and
/// answers the request, and Zeus's certificate is asked about here. A request
/// that can't be used is answered as failed, so Zeus can say why.
extension HomeRouter {
    /// Takes the requests a link from Zeus names, skipping any taken or
    /// answered already. A second zContainer leaves them to the first one,
    /// and answers them so Zeus knows.
    func takeZeusRequests(_ ids: [UUID]) async {
        guard ZeusGroup.root != nil else {
            launchProblem = "zc.zeusRequest.unreachable".loc
            return
        }
        guard sharedModel.multiLCStatus != 2 else {
            turnAwayAsSecondary(ids)
            return
        }
        await take(ids, fromLink: true)
    }

    /// Takes the requests in the app group that no link brought, as when a
    /// guest app got the link: those not taken or answered yet. One that ran
    /// out is left alone, without a word, for Zeus to clear away. A second
    /// zContainer leaves them all to the first.
    ///
    /// When it takes any, `onRoute` hears them just before the first one is
    /// taken, as it hears a link from Zeus, so the root view can bring up the
    /// Home Screen their questions show over. It hears nothing otherwise.
    func rescanZeusRequests(onRoute: @MainActor (HomeRoute) -> Void = { _ in }) async {
        guard sharedModel.multiLCStatus != 2 else {
            return
        }
        await take(ZeusGroup.requestIDsOnDisk(), fromLink: false, onRoute: onRoute)
    }

    /// Reads each request, marks it taken, and hands it on by what it sends.
    /// What goes wrong reading them shows once, however many go wrong.
    /// `onRoute` hears the requests once, before the first one is taken.
    private func take(_ ids: [UUID], fromLink: Bool, onRoute: @MainActor (HomeRoute) -> Void = { _ in }) async {
        var hasShownProblem = false
        var hasTakenAny = false
        // Marks a request taken, once `onRoute` has heard the requests.
        func markTaken(_ id: UUID) {
            if !hasTakenAny {
                hasTakenAny = true
                onRoute(.zeusRequests(ids))
            }
            ZeusGroup.markTaken(id)
        }
        for id in ids where !ZeusGroup.hasTaken(id) && !ZeusGroup.hasResult(for: id) {
            let request: ZeusRequest
            do {
                request = try ZeusGroup.readRequest(id, fromLink: fromLink)
            } catch {
                let groupError = error as? ZeusGroupError
                // A rescan leaves an expired request for a link, which may
                // still name it, and says nothing of a folder Zeus cleared
                // away after it was listed.
                if !fromLink, groupError == .expired || groupError == .missing {
                    continue
                }
                markTaken(id)
                let problem = groupError == .expired ? "zc.zeusRequest.expired".loc : "zc.zeusRequest.unreadable".loc
                if groupError != .missing {
                    ZeusGroup.writeResult(ZeusRequestResult(id: id, outcome: .failed, failure: .unreadable, message: problem))
                }
                if !hasShownProblem {
                    launchProblem = problem
                    hasShownProblem = true
                }
                continue
            }

            markTaken(id)
            switch request.kind {
            case .app:
                onboarding.pendingInstalls.receive(zeusRequest: request)
            case .certificate:
                await reviewZeusCertificate(request)
            }
        }
    }

    /// Asks whether to use the certificate a request from Zeus sends, once
    /// ZSign opens it and it belongs to zContainer's team, as for any
    /// certificate sent to zContainer. Its file is deleted from the group as
    /// it is read, whatever happens next.
    /// A second zContainer never gets here, since `takeZeusRequests` and
    /// `rescanZeusRequests` turn it away first.
    private func reviewZeusCertificate(_ request: ZeusRequest) async {
        let payload: ZeusCertificatePayload
        do {
            payload = try ZeusGroup.takeCertificate(of: request)
        } catch {
            fail(request, because: "zc.zeusRequest.unreadable".loc)
            return
        }
        guard let teamID = await ZeusCertificateImport.teamID(of: payload.certificate, password: payload.password) else {
            fail(request, because: "lc.settings.invalidCertError".loc)
            return
        }
        askToUse(
            CertificateLink(certificateData: payload.certificate, password: payload.password),
            teamID: teamID,
            source: .zeus(requestID: request.id, serialNumber: payload.serialNumber, expiresAt: payload.expiresAt)
        )
    }

    /// Answers a certificate request zContainer couldn't use, and says why.
    private func fail(_ request: ZeusRequest, because problem: String) {
        ZeusGroup.writeResult(ZeusRequestResult(id: request.id, outcome: .failed, failure: .unreadable, message: problem))
        launchProblem = problem
    }

    /// A second zContainer leaves apps and certificates to the first one. It
    /// says so, and answers each request the link names that is in the group
    /// and not answered yet, so Zeus can say so too.
    private func turnAwayAsSecondary(_ ids: [UUID]) {
        let problem = "lc.appList.manageInPrimaryTip".loc
        let onDisk = Set(ZeusGroup.requestIDsOnDisk())
        for id in ids where onDisk.contains(id) && !ZeusGroup.hasResult(for: id) {
            ZeusGroup.writeResult(ZeusRequestResult(id: id, outcome: .failed, failure: .secondary, message: problem))
        }
        launchProblem = problem
    }
}
