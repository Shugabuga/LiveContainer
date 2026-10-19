//
//  ZeusConnection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's link to Zeus, as Settings shows it: the certificate it signs
/// apps with (the one Zeus put inside it, or one imported by hand), what went
/// wrong with it, what Apple says about it, and how Check Setup found the
/// parts Zeus sets up. It also imports, removes and puts back certificates,
/// writing what importing one by hand always wrote.
///
/// Settings makes one when it opens and hands it to its pages through the
/// environment. Nothing here runs at launch: LCZeusCertificate stores Zeus's
/// certificate before the UI loads, and HomeRouter checks it once.
@MainActor
@Observable
final class ZeusConnection {
    /// The link that opens Zeus.
    static let zeusURL = URL(string: "zeus://")

    /// Where the stored certificate came from, or `.none`.
    private(set) var source: ZeusCertificateSource = .none
    /// The team the certificate belongs to, once known. Zeus says it; an
    /// imported certificate is read for it.
    private(set) var teamID: String?
    /// When the certificate expires, once known. Zeus says it; for an imported
    /// certificate, asking Apple about it tells.
    private(set) var expiresAt: Date?
    /// When the certificate was stored.
    private(set) var updatedAt: Date?
    /// What went wrong storing or checking Zeus's certificate, as the person
    /// reads it.
    private(set) var problem: String?
    /// Whether zContainer holds ZeusCertificate.plist, which brings Zeus's
    /// certificate back on the next launch after it is removed.
    private(set) var isBundled = false
    /// Whether this is a second zContainer, which signs with the first one's
    /// certificate and has none of its own to manage.
    private(set) var isSecondary = false
    /// What Apple said about the certificate when last asked.
    private(set) var validity: ZeusCertificateValidity = .unknown
    /// Whether Check Setup is running.
    private(set) var isCheckingSetup = false
    /// Goes up by one whenever a different certificate is stored or none is,
    /// so pages can ask Apple about the new one.
    private(set) var certificateVersion = 0

    /// How Check Setup found each part, for the parts it looked at.
    private var results: [ZeusSetupCheck: ZeusCheckResult] = [:]
    @ObservationIgnored private var teamTask: Task<Void, Never>?

    // The keys importing a certificate by hand writes in the shared defaults,
    // which signing and LCZeusCertificate read.
    private static let certificateDataKey = "LCCertificateData"
    private static let certificatePasswordKey = "LCCertificatePassword"
    private static let certificateDateKey = "LCCertificateUpdateDate"
    /// Remembered in the standard defaults, as LiveContainer did, so the
    /// extensions find the app group the certificate came with.
    private static let appGroupKey = "LCAppGroupID"

    private var defaults: UserDefaults {
        LCUtils.appGroupUserDefault
    }

    /// Reads what is stored, which takes no time. Reading an imported
    /// certificate's team waits for `reload()`, which the pages call when
    /// they appear.
    init() {
        readStoredState()
    }

    /// Whether a certificate is stored, so zContainer can sign apps.
    var hasCertificate: Bool {
        source != .none
    }

    /// Whether the certificate's expiry date has passed.
    var isExpired: Bool {
        expiresAt.map { $0 < .now } ?? false
    }

    /// Why zContainer can't sign apps right now, or nil when nothing is known
    /// to be wrong.
    var attention: ZeusAttention? {
        guard !isSecondary else {
            return nil
        }
        if !hasCertificate {
            return .notSetUp
        }
        if problem != nil || result(for: .signing).failure != nil {
            return .problem
        }
        if isExpired {
            return .expired
        }
        if validity == .revoked {
            return .revoked
        }
        return nil
    }

    /// One line on the certificate for the card at the top of Settings: its
    /// team and when it expires, as far as they are known.
    var summary: String {
        if isSecondary {
            return "lc.settings.multiLCIsSecond".loc
        }
        var parts: [String] = []
        switch source {
        case .none:
            return "zc.settings.zeus.noCertificate".loc
        case .imported:
            parts.append("zc.settings.zeus.importedCertificate".loc)
        case .zeus:
            break
        }
        if let teamID {
            parts.append("lc.zeusCertificate.team %@".localizeWithFormat(teamID))
        }
        if let expiresAt {
            let date = expiresAt.formatted(date: .abbreviated, time: .omitted)
            let key = isExpired ? "lc.zeusCertificate.expired %@" : "lc.zeusCertificate.expires %@"
            parts.append(key.localizeWithFormat(date))
        }
        return parts.joined(separator: " · ")
    }

    /// How Check Setup found one part.
    func result(for check: ZeusSetupCheck) -> ZeusCheckResult {
        results[check] ?? .notChecked
    }

    /// Reads the stored certificate again, with what LCZeusCertificate and
    /// the launch check recorded about it, and looks at the parts of the
    /// setup that take no time: the app group and the keychain groups. For
    /// an imported certificate, it also reads which team it belongs to.
    func reload() {
        readStoredState()
        if source == .imported && teamID == nil {
            readImportedTeam()
        }
    }

    private func readStoredState() {
        isSecondary = DataManager.shared.model.multiLCStatus == 2
        isBundled = LCZeusCertificate.isBundled()
        problem = ZeusCertificate.problem
        updatedAt = defaults.object(forKey: Self.certificateDateKey) as? Date

        let zeusCertificate = ZeusCertificate.stored
        if LCSharedUtils.certificatePassword() == nil {
            source = .none
        } else if zeusCertificate != nil {
            source = .zeus
        } else {
            source = .imported
        }

        switch source {
        case .none:
            teamID = nil
            expiresAt = nil
        case .zeus:
            teamID = zeusCertificate?.teamID
            expiresAt = zeusCertificate?.expiresAt ?? expiresAt
        case .imported:
            break
        }

        results[.sharedStorage] = ZeusEntitlements.hasSharedStorage
            ? .passed
            : .failed("zc.settings.setup.sharedStorageMissing".loc)
        results[.separateLogins] = ZeusEntitlements.hasLoginGroups ? .passed : .missing
    }

    /// Asks Apple whether the certificate is still good, as the JIT-less
    /// diagnosis does, which also tells when it expires. It asks again only
    /// when there's no answer yet for this certificate.
    func checkCertificateIfNeeded() async {
        switch validity {
        case .unknown, .unavailable:
            break
        case .checking, .valid, .revoked:
            return
        }
        guard hasCertificate else {
            return
        }
        let version = certificateVersion
        validity = .checking
        let answer = await Self.askApple()
        guard version == certificateVersion else {
            return
        }
        if let date = answer.expiresAt {
            expiresAt = date
        }
        if let team = answer.teamID, !team.isEmpty {
            teamID = team
        }
        switch answer.status {
        case 0:
            validity = .valid
        case 1:
            validity = .revoked
        default:
            validity = .unavailable(answer.error?.loc ?? "lc.common.unknown".loc)
        }
    }

    /// Check Setup: looks at the app group and the keychain groups again, then
    /// signs a test library with the certificate, the way apps are signed, and
    /// checks that iOS accepts it, as it has to for apps to open without JIT.
    /// When that works, a failed check recorded at launch no longer stands.
    func checkSetup() async {
        guard !isCheckingSetup else {
            return
        }
        isCheckingSetup = true
        defer {
            isCheckingSetup = false
        }
        reload()

        guard hasCertificate else {
            results[.signing] = .failed("zc.settings.setup.noCertificate".loc)
            return
        }
        results[.signing] = .checking
        let (passed, error) = await ZeusCertificate.validateJITLessSetup()
        if passed {
            results[.signing] = .passed
            ZeusCertificate.clearFailedCheck()
            problem = ZeusCertificate.problem
        } else {
            var reason = "lc.jitlessSetup.error.testLibLoadFailed".loc
            if let error {
                reason += "\n" + error.localizedDescription.loc
            }
            results[.signing] = .failed(reason)
        }
    }

    /// Stores a .p12 of the person's own in place of the current certificate,
    /// once ZSign opens it with the password. Throws the error to show when it
    /// doesn't.
    func importCertificate(_ data: Data, password: String) async throws {
        // ZSign opens the .p12 on the calling thread, so it runs away from
        // the main one.
        let team = await Task.detached(priority: .userInitiated) {
            LCUtils.getCertTeamId(withKeyData: data, password: password)
        }.value
        guard team != nil else {
            throw "lc.settings.invalidCertError".loc
        }
        defaults.set(data, forKey: Self.certificateDataKey)
        defaults.set(password, forKey: Self.certificatePasswordKey)
        defaults.set(Date.now, forKey: Self.certificateDateKey)
        ZeusCertificate.forgetStored()
        UserDefaults.standard.set(LCSharedUtils.appGroupID(), forKey: Self.appGroupKey)
        certificateChanged()
    }

    /// Forgets the certificate, so zContainer can't sign apps until it has
    /// one again.
    func removeCertificate() {
        defaults.removeObject(forKey: Self.certificateDataKey)
        defaults.removeObject(forKey: Self.certificatePasswordKey)
        defaults.removeObject(forKey: Self.certificateDateKey)
        ZeusCertificate.forgetStored()
        UserDefaults.standard.removeObject(forKey: Self.appGroupKey)
        certificateChanged()
    }

    /// Puts back the certificate Zeus put inside zContainer, replacing one
    /// imported by hand, and checks it as the launch does. What goes wrong is
    /// recorded, so it shows in `problem` afterwards.
    func useZeusCertificate() async {
        _ = LCZeusCertificate.importReplacingStoredCertificate()
        _ = await ZeusCertificate.checkIfNeeded()
        certificateChanged()
    }

    /// Starts over with whatever certificate is stored now: nothing is known
    /// about it from Apple or Check Setup yet.
    private func certificateChanged() {
        teamTask?.cancel()
        validity = .unknown
        results[.signing] = nil
        teamID = nil
        expiresAt = nil
        certificateVersion += 1
        reload()
    }

    /// Reads which team an imported certificate belongs to, which takes ZSign
    /// opening it, away from the main thread.
    private func readImportedTeam() {
        guard let data = LCUtils.certificateData(),
              let password = LCSharedUtils.certificatePassword() else {
            return
        }
        let version = certificateVersion
        teamTask?.cancel()
        teamTask = Task { [weak self] in
            let team = await Task.detached(priority: .utility) {
                LCUtils.getCertTeamId(withKeyData: data, password: password)
            }.value
            guard let self, !Task.isCancelled, version == self.certificateVersion else {
                return
            }
            self.teamID = team
        }
    }

    /// Asks Apple about the stored certificate over OCSP, through ZSign.
    /// Status 0 means good and 1 revoked; anything else comes with the error.
    private static func askApple() async -> (status: Int32, expiresAt: Date?, teamID: String?, error: String?) {
        await withCheckedContinuation { continuation in
            _ = LCUtils.validateCertificate { status, expiresAt, teamID, error in
                continuation.resume(returning: (status, expiresAt, teamID, error))
            }
        }
    }
}
