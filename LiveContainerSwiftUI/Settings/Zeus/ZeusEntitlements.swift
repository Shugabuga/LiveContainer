//
//  ZeusEntitlements.swift
//  LiveContainerSwiftUI
//

import Foundation
import Security

/// Reads what Zeus gave zContainer when it signed it, for the quick parts of
/// Check Setup.
enum ZeusEntitlements {
    /// The keychain group the first container uses, after the team ID. The
    /// others add ".1" to ".127" to it (LiveContainer/Tweaks/SecItem.m).
    private static let loginGroup = "app.reiko.zcontainer.shared"

    /// Whether zContainer can reach its app group's folder.
    static var hasSharedStorage: Bool {
        LCSharedUtils.appGroupPath() != nil
    }

    /// Whether zContainer can use the keychain groups that keep each
    /// container's sign-ins apart. It asks the keychain for the first group
    /// and the last one the way an app inside does when it opens (SecItem.m),
    /// so the team's wildcard, `TEAM.*`, doesn't count: the keychain takes it
    /// as the name of a group, not a pattern, so the apps inside find none of
    /// theirs and all share one keychain.
    ///
    /// The hooks in SecItem.m, which move every keychain query into the
    /// container's group, are set up only in the process of an app inside
    /// (LCBootstrap.m), never in zContainer's own, so these queries keep the
    /// group they name. Entitlements don't change while zContainer runs, so
    /// it asks once.
    static let hasLoginGroups = canUseLoginGroups()

    private static func canUseLoginGroups() -> Bool {
        guard let team = LCSharedUtils.teamIdentifier() else {
            return false
        }
        let first = "\(team).\(loginGroup)"
        let last = "\(first).\(SharedModel.keychainAccessGroupCount - 1)"
        return canUse(first) && canUse(last)
    }

    /// Whether the keychain lets zContainer look in a group. It answers
    /// errSecMissingEntitlement when zContainer's entitlements leave the group
    /// out; the item asked for never exists, so any other answer means it may.
    private static func canUse(_ group: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "NonExistentKey",
            kSecAttrService: "NonExistentService",
            kSecAttrAccessGroup: group,
            kSecReturnData: false,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) != errSecMissingEntitlement
    }
}
