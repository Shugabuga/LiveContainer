//
//  ZeusEntitlements.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Reads what Zeus gave zContainer when it signed it, from zContainer's own
/// entitlements, for the quick parts of Check Setup.
enum ZeusEntitlements {
    /// The keychain group the first container uses, after the team ID. The
    /// others add ".1" to ".127" to it (LiveContainer/Tweaks/SecItem.m).
    private static let loginGroup = "app.reiko.zcontainer.shared"

    /// Whether zContainer can reach its app group's folder.
    static var hasSharedStorage: Bool {
        LCSharedUtils.appGroupPath() != nil
    }

    /// Whether zContainer holds the keychain group of every container, by
    /// name or through the team's wildcard.
    static var hasLoginGroups: Bool {
        guard let team = LCSharedUtils.teamIdentifier(),
              let groups = value(for: "keychain-access-groups") as? [String] else {
            return false
        }
        let held = Set(groups)
        if held.contains("\(team).*") {
            return true
        }
        let first = "\(team).\(loginGroup)"
        let all = [first] + (1..<SharedModel.keychainAccessGroupCount).map { "\(first).\($0)" }
        return held.isSuperset(of: all)
    }

    /// The value of one of zContainer's entitlements, or nil when it has none.
    private static func value(for entitlement: String) -> Any? {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return nil
        }
        defer {
            Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(task)).release()
        }
        return SecTaskCopyValueForEntitlement(task, entitlement as CFString, nil)?.takeRetainedValue()
    }
}
