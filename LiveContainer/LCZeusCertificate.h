@import Foundation;

// The certificate Zeus puts inside this app when it signs it.
//
// The main Info.plist marks the app with ZeusCompanion = {Kind: zContainer,
// Protocol: 1}. When the user allows it, Zeus then writes ZeusCertificate.plist
// into the root of the app before signing it, so the signature seals it: a
// dictionary with "Certificate" (a PKCS#12 of the signing certificate and its
// private key), "Password", "TeamID", "SerialNumber" (hex), "ExpiresAt"
// (optional) and "Protocol" (1).
//
// importIfNeeded stores that certificate where importing one by hand stores it,
// so signing and the check before launching an app find it. It only reads the
// file: the UI checks the certificate itself with ZSign afterwards
// (ZeusCertificate.swift), since loading ZSign here would load OpenSSL into
// every app this one runs.
@interface LCZeusCertificate : NSObject

// Stores the certificate from ZeusCertificate.plist when it is new: its serial
// number differs from the one stored last, or no certificate is stored. Returns
// whether it stored one. Does nothing when the app holds no such file.
+ (BOOL)importIfNeeded;

// Stores the certificate from ZeusCertificate.plist even when it was stored
// before, replacing one imported by hand. Returns whether it stored it.
+ (BOOL)importReplacingStoredCertificate;

// Whether the app holds a ZeusCertificate.plist.
+ (BOOL)isBundled;

// A build of this fork briefly kept the shared defaults in the standard ones when
// the app had no app group. Moves a certificate it stored there to the shared
// defaults, unless one is stored there already, and leaves no copy behind.
+ (void)moveCertificateOutOfStandardDefaults;

@end

// Keys in the shared defaults (NSUserDefaults.lcSharedDefaults), next to
// LCCertificateData, LCCertificatePassword and LCCertificateUpdateDate.

// BOOL: the stored certificate is the one Zeus put inside the app. Importing
// or removing a certificate by hand clears it.
extern NSString * const LCCertificateFromZeusKey;
// The serial number of the last ZeusCertificate.plist stored. It stays when a
// certificate is imported by hand, so that one is kept until Zeus brings a new
// certificate.
extern NSString * const LCZeusCertificateSerialNumberKey;
extern NSString * const LCZeusCertificateTeamIDKey;
extern NSString * const LCZeusCertificateExpiresAtKey;
// BOOL: the UI has yet to check the certificate stored, or to show a problem.
extern NSString * const LCZeusCertificateNeedsCheckKey;
// What went wrong with Zeus's certificate, one of the LCZeusCertificateProblem
// values below, and a detail for some of them.
extern NSString * const LCZeusCertificateProblemKey;
extern NSString * const LCZeusCertificateProblemDetailKey;

// The file is not a dictionary holding everything listed above.
extern NSString * const LCZeusCertificateProblemUnreadable;
// The file follows another version of the hand-off (the detail).
extern NSString * const LCZeusCertificateProblemProtocol;
// The certificate belongs to another team (the detail) than the one that
// signed this app, so the apps it signs couldn't run here.
extern NSString * const LCZeusCertificateProblemTeam;
// Set by the UI: ZSign can't open the certificate with its password.
extern NSString * const LCZeusCertificateProblemPassword;
// Set by the UI: the JIT-less check failed (the detail is its error).
extern NSString * const LCZeusCertificateProblemCheck;
