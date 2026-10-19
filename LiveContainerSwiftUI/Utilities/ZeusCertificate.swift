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

    /// Whether the last check of the setup passed: the JIT-less check after
    /// Zeus brings a certificate, or Check Setup in Settings or onboarding.
    /// Nil until one has run for the certificate stored now. Kept in the
    /// standard defaults, since the check signs and loads a library in this
    /// app, which a second zContainer sharing the app group would do again.
    /// Onboarding stays away at launch once a certificate is stored and this
    /// is true.
    static var lastCheckPassed: Bool? {
        get {
            UserDefaults.standard.object(forKey: lastCheckPassedKey) as? Bool
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: lastCheckPassedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastCheckPassedKey)
            }
        }
    }

    private static let lastCheckPassedKey = "ZCLastSetupCheckPassed"

    /// The team of the certificate Zeus put inside the app, when LCZeusCertificate
    /// left it out because it belongs to another team than zContainer's.
    static var mismatchedTeamID: String? {
        guard defaults.string(forKey: LCZeusCertificateProblemKey) == LCZeusCertificateProblemTeam else {
            return nil
        }
        return defaults.string(forKey: LCZeusCertificateProblemDetailKey)
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
            lastCheckPassed = false
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
        lastCheckPassed = true
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
        lastCheckPassed = false
        defaults.set(code, forKey: LCZeusCertificateProblemKey)
        if let detail {
            defaults.set(detail, forKey: LCZeusCertificateProblemDetailKey)
        } else {
            defaults.removeObject(forKey: LCZeusCertificateProblemDetailKey)
        }
    }

    /// The JIT-less check: signs a test library with the stored certificate
    /// and asks iOS whether it accepts the signature. Settings' Check Setup,
    /// onboarding, the JIT-less diagnosis and the check after Zeus brings a
    /// certificate all run it, sometimes at once, and every run signs the
    /// same copy of the library in the temporary folder, so each one waits
    /// for the one before it.
    @MainActor
    static func validateJITLessSetup() async -> (Bool, Error?) {
        let previous = runningCheck
        let check = Task { @MainActor in
            _ = await previous?.value
            return await signTestLibrary()
        }
        runningCheck = check
        return await check.value
    }

    /// The last JIT-less check started, which the next one waits for.
    @MainActor private static var runningCheck: Task<(Bool, Error?), Never>?

    /// LCUtils.validateJITLessSetup waits for ZSign on the calling thread, so
    /// it runs off the main thread here; it reports back on the main queue.
    private static func signTestLibrary() async -> (Bool, Error?) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                LCUtils.validateJITLessSetup { success, error in
                    continuation.resume(returning: (success, error))
                }
            }
        }
    }
}
