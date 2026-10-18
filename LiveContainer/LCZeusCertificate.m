#import "LCZeusCertificate.h"
#import "LCSharedUtils.h"
#import "utils.h"

NSString * const LCCertificateFromZeusKey = @"LCCertificateFromZeus";
NSString * const LCZeusCertificateSerialNumberKey = @"LCZeusCertificateSerialNumber";
NSString * const LCZeusCertificateTeamIDKey = @"LCZeusCertificateTeamID";
NSString * const LCZeusCertificateExpiresAtKey = @"LCZeusCertificateExpiresAt";
NSString * const LCZeusCertificateNeedsCheckKey = @"LCZeusCertificateNeedsCheck";
NSString * const LCZeusCertificateProblemKey = @"LCZeusCertificateProblem";
NSString * const LCZeusCertificateProblemDetailKey = @"LCZeusCertificateProblemDetail";

NSString * const LCZeusCertificateProblemUnreadable = @"unreadable";
NSString * const LCZeusCertificateProblemProtocol = @"protocol";
NSString * const LCZeusCertificateProblemTeam = @"team";
NSString * const LCZeusCertificateProblemPassword = @"password";
NSString * const LCZeusCertificateProblemCheck = @"check";

// The version of the hand-off this app follows, the one its ZeusCompanion
// marker gives.
static const NSInteger LCZeusCertificateProtocol = 1;

// The keys importing a certificate by hand writes (LCSettingsView).
static NSString * const LCCertificateDataKey = @"LCCertificateData";
static NSString * const LCCertificatePasswordKey = @"LCCertificatePassword";
static NSString * const LCCertificateUpdateDateKey = @"LCCertificateUpdateDate";

extern NSUserDefaults *lcUserDefaults;

@implementation LCZeusCertificate

+ (NSString *)bundledPath {
    NSBundle *bundle = NSUserDefaults.lcMainBundle ?: NSBundle.mainBundle;
    return [bundle.bundlePath stringByAppendingPathComponent:@"ZeusCertificate.plist"];
}

+ (BOOL)isBundled {
    return [NSFileManager.defaultManager fileExistsAtPath:self.bundledPath];
}

+ (void)moveCertificateOutOfStandardDefaults {
    NSUserDefaults *standard = lcUserDefaults ?: NSUserDefaults.standardUserDefaults;
    NSUserDefaults *shared = NSUserDefaults.lcSharedDefaults;
    // LiveContainer itself never stores the certificate in the standard defaults.
    if (!shared || ![standard objectForKey:LCCertificateDataKey]) {
        return;
    }
    BOOL move = ![shared objectForKey:LCCertificateDataKey];
    for (NSString *key in @[LCCertificateDataKey, LCCertificatePasswordKey, LCCertificateUpdateDateKey,
                            LCCertificateFromZeusKey, LCZeusCertificateSerialNumberKey, LCZeusCertificateTeamIDKey,
                            LCZeusCertificateExpiresAtKey, LCZeusCertificateNeedsCheckKey,
                            LCZeusCertificateProblemKey, LCZeusCertificateProblemDetailKey]) {
        if (move) {
            id value = [standard objectForKey:key];
            if (value) {
                [shared setObject:value forKey:key];
            } else {
                [shared removeObjectForKey:key];
            }
        }
        [standard removeObjectForKey:key];
    }
}

+ (BOOL)importIfNeeded {
    return [self importReplacingStored:NO];
}

+ (BOOL)importReplacingStoredCertificate {
    return [self importReplacingStored:YES];
}

+ (BOOL)importReplacingStored:(BOOL)replace {
    NSString *path = self.bundledPath;
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        return NO;
    }
    NSUserDefaults *defaults = NSUserDefaults.lcSharedDefaults;

    NSData *contents = [NSData dataWithContentsOfFile:path];
    id file = contents ? [NSPropertyListSerialization propertyListWithData:contents options:NSPropertyListImmutable format:nil error:nil] : nil;
    if (![file isKindOfClass:NSDictionary.class]) {
        [self report:LCZeusCertificateProblemUnreadable detail:nil defaults:defaults];
        return NO;
    }

    NSNumber *protocol = file[@"Protocol"];
    if (![protocol isKindOfClass:NSNumber.class]) {
        [self report:LCZeusCertificateProblemUnreadable detail:nil defaults:defaults];
        return NO;
    }
    if (protocol.integerValue != LCZeusCertificateProtocol) {
        [self report:LCZeusCertificateProblemProtocol detail:protocol.stringValue defaults:defaults];
        return NO;
    }

    NSData *certificate = file[@"Certificate"];
    NSString *password = file[@"Password"];
    NSString *teamID = file[@"TeamID"];
    NSString *serialNumber = file[@"SerialNumber"];
    NSDate *expiresAt = file[@"ExpiresAt"];
    if (![certificate isKindOfClass:NSData.class] || certificate.length == 0 ||
        ![password isKindOfClass:NSString.class] ||
        ![teamID isKindOfClass:NSString.class] || teamID.length == 0 ||
        ![serialNumber isKindOfClass:NSString.class] || serialNumber.length == 0) {
        [self report:LCZeusCertificateProblemUnreadable detail:nil defaults:defaults];
        return NO;
    }
    if (![expiresAt isKindOfClass:NSDate.class]) {
        expiresAt = nil;
    }

    // Done already, unless the certificate was removed since. A certificate
    // imported by hand since then stays until Zeus brings a new one.
    BOOL stored = [defaults objectForKey:LCCertificateDataKey] && [defaults objectForKey:LCCertificatePasswordKey];
    NSString *storedSerialNumber = [defaults stringForKey:LCZeusCertificateSerialNumberKey];
    if (!replace && stored && storedSerialNumber && [storedSerialNumber caseInsensitiveCompare:serialNumber] == NSOrderedSame) {
        return NO;
    }

    // Apps signed with another team's certificate can't run inside this app.
    NSString *ownTeamID = LCSharedUtils.teamIdentifier;
    if (ownTeamID.length > 0 && ![ownTeamID isEqualToString:teamID]) {
        [self report:LCZeusCertificateProblemTeam detail:teamID defaults:defaults];
        return NO;
    }

    [defaults setObject:certificate forKey:LCCertificateDataKey];
    [defaults setObject:password forKey:LCCertificatePasswordKey];
    [defaults setObject:NSDate.date forKey:LCCertificateUpdateDateKey];
    [defaults setBool:YES forKey:LCCertificateFromZeusKey];
    [defaults setObject:serialNumber forKey:LCZeusCertificateSerialNumberKey];
    [defaults setObject:teamID forKey:LCZeusCertificateTeamIDKey];
    if (expiresAt) {
        [defaults setObject:expiresAt forKey:LCZeusCertificateExpiresAtKey];
    } else {
        [defaults removeObjectForKey:LCZeusCertificateExpiresAtKey];
    }
    [defaults removeObjectForKey:LCZeusCertificateProblemKey];
    [defaults removeObjectForKey:LCZeusCertificateProblemDetailKey];
    [defaults setBool:YES forKey:LCZeusCertificateNeedsCheckKey];
    // Like importing by hand: remember the app group, so it isn't looked up again.
    if (LCSharedUtils.hasAppGroup) {
        [lcUserDefaults ?: NSUserDefaults.standardUserDefaults setObject:LCSharedUtils.appGroupID forKey:@"LCAppGroupID"];
    }
    NSLog(@"[LC] Stored the certificate Zeus included, for team %@", teamID);
    return YES;
}

// Records a problem for the UI to show, once: it is found again on every
// launch until Zeus signs the app again.
+ (void)report:(NSString *)problem detail:(NSString *)detail defaults:(NSUserDefaults *)defaults {
    NSLog(@"[LC] Can't use the certificate Zeus included: %@", problem);
    BOOL known = [[defaults stringForKey:LCZeusCertificateProblemKey] isEqualToString:problem] &&
        ((!detail && ![defaults stringForKey:LCZeusCertificateProblemDetailKey]) ||
         [[defaults stringForKey:LCZeusCertificateProblemDetailKey] isEqualToString:detail]);
    if (known) {
        return;
    }
    [defaults setObject:problem forKey:LCZeusCertificateProblemKey];
    if (detail) {
        [defaults setObject:detail forKey:LCZeusCertificateProblemDetailKey];
    } else {
        [defaults removeObjectForKey:LCZeusCertificateProblemDetailKey];
    }
    [defaults setBool:YES forKey:LCZeusCertificateNeedsCheckKey];
}

@end
