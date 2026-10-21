@import Foundation;

@interface LCSharedUtils : NSObject
+ (NSString*) teamIdentifier;
+ (NSString *)appGroupID;
+ (NSURL*) appGroupPath;
+ (BOOL)hasAppGroup;
// Whether the app group is the one zContainer shares with Zeus
// (group.app.reiko.zeus followed by the team), where Zeus leaves its requests.
+ (BOOL)sharesZeusGroup;
// Copies the settings saved while zContainer had no app group (the "Unknown"
// suite in its own preferences) into the group's, once per group. Settings the
// group holds already are kept, and the certificate is only copied into a group
// without one. The first time zContainer has a group, it also moves the app
// groups of apps inside into it, except names the group holds already. The main
// app calls it at launch, before anything reads them.
+ (void)migrateSharedDefaultsIfNeeded;
+ (NSString *)certificatePassword;
+ (BOOL)launchToGuestAppWithClassicMode:(NSUInteger)classicMode;
+ (BOOL)launchToGuestAppWithURL:(NSURL *)url;
+ (void)setWebPageUrlForNextLaunch:(NSString*)urlString;
+ (BOOL)isLCSchemeInUse:(NSString*)lc;
+ (NSString*)getContainerUsingLCSchemeWithFolderName:(NSString*)folderName;
+ (void)setContainerUsingByLC:(NSString*)lc folderName:(NSString*)folderName auditToken:(uint64_t)val57;
+ (void)moveSharedAppFolderBack;
+ (NSBundle*)findBundleWithBundleId:(NSString*)bundleId isSharedAppOut:(bool*)isSharedAppOut;
+ (void)dumpPreferenceToPath:(NSString*)plistLocationTo dataUUID:(NSString*)dataUUID;
+ (NSString*)findDefaultContainerWithBundleId:(NSString*)bundleId;
// The URL scheme this zContainer answers to (see LCSharedUtils.m).
+ (NSString *)hostAppUrlScheme;
+ (NSArray<NSString*>*)lcUnorderedUrlSchemes;
+ (NSArray<NSString*>*)lcUrlSchemes;
@end
