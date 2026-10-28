//
//  ZeusCertificateImport.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Stores a .p12 as the certificate zContainer signs apps with, writing what
/// importing one by hand always wrote. Settings' Import Certificate, a
/// certificate link and a .p12 opened with zContainer all store it here, as
/// does the certificate Zeus leaves in the app group the two apps share;
/// LCZeusCertificate stores the one Zeus puts inside the app itself.
enum ZeusCertificateImport {
    // The keys in the shared defaults, which signing and LCZeusCertificate read.
    static let certificateDataKey = "LCCertificateData"
    static let certificatePasswordKey = "LCCertificatePassword"
    static let certificateDateKey = "LCCertificateUpdateDate"
    /// Remembered in the standard defaults, as LiveContainer did.
    /// LCSharedUtils.appGroupID prefers the group shared with Zeus and falls
    /// back to this one; the extensions keep their own standard defaults, so
    /// only the app reads it.
    static let appGroupKey = "LCAppGroupID"

    /// The team a .p12 belongs to, once ZSign opens it with the password, or
    /// nil when it doesn't open.
    static func teamID(of data: Data, password: String) async -> String? {
        // ZSign opens the .p12 on the calling thread, so it runs away from
        // the main one.
        await Task.detached(priority: .userInitiated) {
            LCUtils.getCertTeamId(withKeyData: data, password: password)
        }.value
    }

    /// Stores a .p12 that ZSign opened with the password, in place of the
    /// current certificate. The stored certificate is no longer Zeus's, and
    /// nothing is known yet about whether it signs: Check Setup tells.
    @MainActor
    static func store(_ data: Data, password: String) {
        let defaults = LCUtils.appGroupUserDefault
        defaults.set(data, forKey: certificateDataKey)
        defaults.set(password, forKey: certificatePasswordKey)
        defaults.set(Date.now, forKey: certificateDateKey)
        ZeusCertificate.forgetStored()
        ZeusCertificate.lastCheckPassed = nil
        rememberAppGroup()
    }

    /// Stores the certificate Zeus left in the app group, once ZSign opened
    /// it and found `teamID`, as Zeus's own certificate, the way
    /// LCZeusCertificate stores the one inside the app: Settings shows its
    /// team and expiry, and a problem recorded for the last one no longer
    /// stands. Nothing is known yet about whether it signs. HomeRouter checks
    /// it right after, or onboarding's steps do, so the launch check leaves
    /// it alone.
    ///
    /// When the app holds a certificate of its own, the serial number recorded
    /// is that file's: LCZeusCertificate stores that file again at launch
    /// whenever the serial number differs, which would put the older
    /// certificate back, and reports its problem again when it couldn't store
    /// it. When that file gives no serial number, the one recorded stays.
    @MainActor
    static func storeFromZeus(_ data: Data, password: String, teamID: String, serialNumber: String, expiresAt: Date?) {
        let defaults = LCUtils.appGroupUserDefault
        defaults.set(data, forKey: certificateDataKey)
        defaults.set(password, forKey: certificatePasswordKey)
        defaults.set(Date.now, forKey: certificateDateKey)
        defaults.set(true, forKey: LCCertificateFromZeusKey)
        if let bundledSerialNumber = LCZeusCertificate.bundledSerialNumber() {
            defaults.set(bundledSerialNumber, forKey: LCZeusCertificateSerialNumberKey)
        } else if !LCZeusCertificate.isBundled() {
            defaults.set(serialNumber, forKey: LCZeusCertificateSerialNumberKey)
        }
        defaults.set(teamID, forKey: LCZeusCertificateTeamIDKey)
        if let expiresAt {
            defaults.set(expiresAt, forKey: LCZeusCertificateExpiresAtKey)
        } else {
            defaults.removeObject(forKey: LCZeusCertificateExpiresAtKey)
        }
        defaults.removeObject(forKey: LCZeusCertificateProblemKey)
        defaults.removeObject(forKey: LCZeusCertificateProblemDetailKey)
        defaults.set(false, forKey: LCZeusCertificateNeedsCheckKey)
        ZeusCertificate.lastCheckPassed = nil
        rememberAppGroup()
    }

    /// Remembers the app group the certificate came with, or forgets the one
    /// remembered when zContainer has none, so the placeholder name
    /// LCSharedUtils gives then is never kept as if it were a group.
    private static func rememberAppGroup() {
        if LCSharedUtils.hasAppGroup() {
            UserDefaults.standard.set(LCSharedUtils.appGroupID(), forKey: appGroupKey)
        } else {
            UserDefaults.standard.removeObject(forKey: appGroupKey)
        }
    }
}
