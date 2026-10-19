//
//  ZeusCertificate.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The certificate Zeus put inside this app when it signed it. LCZeusCertificate
/// stores it at launch, before anything needs it; this is what the UI shows of
/// it and the check it runs on it afterwards.
struct ZeusCertificate {
    let teamID: String
    let expiresAt: Date?

    private static var defaults: UserDefaults { LCUtils.appGroupUserDefault }

    /// The stored certificate, when it is the one Zeus put inside the app.
    static var stored: ZeusCertificate? {
        guard defaults.bool(forKey: LCCertificateFromZeusKey),
              let teamID = defaults.string(forKey: LCZeusCertificateTeamIDKey) else {
            return nil
        }
        return ZeusCertificate(teamID: teamID, expiresAt: defaults.object(forKey: LCZeusCertificateExpiresAtKey) as? Date)
    }

    /// One line for Settings: the team and when the certificate expires.
    var summary: String {
        var parts = ["lc.zeusCertificate.team %@".localizeWithFormat(teamID)]
        if let expiresAt {
            let date = expiresAt.formatted(date: .abbreviated, time: .omitted)
            let key = expiresAt < .now ? "lc.zeusCertificate.expired %@" : "lc.zeusCertificate.expires %@"
            parts.append(key.localizeWithFormat(date))
        }
        return parts.joined(separator: " · ")
    }

    /// What went wrong storing or checking Zeus's certificate, as the user reads it.
    static var problem: String? {
        guard let code = defaults.string(forKey: LCZeusCertificateProblemKey) else {
            return nil
        }
        let detail = defaults.string(forKey: LCZeusCertificateProblemDetailKey) ?? ""
        switch code {
        case LCZeusCertificateProblemProtocol:
            return "lc.zeusCertificate.problem.protocol".loc
        case LCZeusCertificateProblemTeam:
            let ownTeamID = LCSharedUtils.teamIdentifier() ?? "lc.common.unknown".loc
            return "lc.zeusCertificate.problem.team %@ %@".localizeWithFormat(detail, ownTeamID)
        case LCZeusCertificateProblemPassword:
            return "lc.zeusCertificate.problem.password".loc
        case LCZeusCertificateProblemCheck:
            return "lc.zeusCertificate.problem.check %@".localizeWithFormat(detail.loc)
        default:
            return "lc.zeusCertificate.problem.unreadable".loc
        }
    }

    /// Checks the certificate LCZeusCertificate stored the way importing one by
    /// hand does, then runs the JIT-less check: ZSign has to open it with its
    /// password, and a test library signed with it has to load. It runs once
    /// after each import and stays quiet unless something fails. Returns the
    /// problem to show, including one LCZeusCertificate found at launch.
    static func checkIfNeeded() async -> String? {
        guard defaults.bool(forKey: LCZeusCertificateNeedsCheckKey) else {
            return nil
        }
        defaults.set(false, forKey: LCZeusCertificateNeedsCheckKey)
        if let problem {
            return problem
        }
        guard let stored,
              let certificateData = LCUtils.certificateData(),
              let password = LCSharedUtils.certificatePassword() else {
            return nil
        }

        let certificateTeamID = await Task.detached(priority: .utility) {
            LCUtils.getCertTeamId(withKeyData: certificateData, password: password)
        }.value
        guard let certificateTeamID else {
            record(LCZeusCertificateProblemPassword)
            return problem
        }
        guard certificateTeamID == stored.teamID else {
            record(LCZeusCertificateProblemTeam, detail: certificateTeamID)
            return problem
        }

        let (passed, error) = await validateJITLessSetup()
        guard passed else {
            record(LCZeusCertificateProblemCheck, detail: error?.localizedDescription ?? "lc.common.unknown")
            return problem
        }
        return nil
    }

    /// After importing or removing a certificate by hand: the stored one is no
    /// longer Zeus's. The serial number stays, so Zeus's certificate comes back
    /// only when Zeus brings a new one (or when none is stored).
    static func forgetStored() {
        defaults.set(false, forKey: LCCertificateFromZeusKey)
        defaults.set(false, forKey: LCZeusCertificateNeedsCheckKey)
        defaults.removeObject(forKey: LCZeusCertificateProblemKey)
        defaults.removeObject(forKey: LCZeusCertificateProblemDetailKey)
    }

    /// After Check Setup passed in Settings: a failed JIT-less check recorded
    /// earlier no longer stands, since signing works now. Other problems stay.
    static func clearFailedCheck() {
        guard defaults.string(forKey: LCZeusCertificateProblemKey) == LCZeusCertificateProblemCheck else {
            return
        }
        defaults.removeObject(forKey: LCZeusCertificateProblemKey)
        defaults.removeObject(forKey: LCZeusCertificateProblemDetailKey)
    }

    private static func record(_ code: String, detail: String? = nil) {
        defaults.set(code, forKey: LCZeusCertificateProblemKey)
        if let detail {
            defaults.set(detail, forKey: LCZeusCertificateProblemDetailKey)
        } else {
            defaults.removeObject(forKey: LCZeusCertificateProblemDetailKey)
        }
    }

    /// The JIT-less check: signs a test library with the stored certificate
    /// and asks iOS whether it accepts the signature. LCUtils.validateJITLessSetup
    /// waits for ZSign on the calling thread, so it runs off the main thread
    /// here; it reports back on the main queue. Settings' Check Setup runs it
    /// too.
    static func validateJITLessSetup() async -> (Bool, Error?) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                LCUtils.validateJITLessSetup { success, error in
                    continuation.resume(returning: (success, error))
                }
            }
        }
    }
}
