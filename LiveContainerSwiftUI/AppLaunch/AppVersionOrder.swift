//
//  AppVersionOrder.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Orders two versions of an app the way Zeus orders its releases
/// (`RunningZeus.compare` in Zeus): dotted numbers part by part, numerically,
/// with missing parts as 0, so 1.10 comes after 1.2 and 3.0 equals 3.0.0.
/// Builds only break a tie, and only when both are known.
enum AppVersionOrder {
    /// How `version` and `build` stand against `otherVersion` and
    /// `otherBuild`: `.orderedAscending` when they are older,
    /// `.orderedDescending` when they are newer, `.orderedSame` when they are
    /// the same version and the builds match or one is unknown.
    static func compare(version: String, build: String?, with otherVersion: String, build otherBuild: String?) -> ComparisonResult {
        let versionOrder = compareParts(version, otherVersion)
        guard versionOrder == .orderedSame, let build, let otherBuild else {
            return versionOrder
        }
        return compareParts(build, otherBuild)
    }

    /// Compares dotted numbers part by part, numerically, with missing parts
    /// as 0.
    private static func compareParts(_ lhs: String, _ rhs: String) -> ComparisonResult {
        var left = lhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        var right = rhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let count = max(left.count, right.count)
        left += Array(repeating: "0", count: count - left.count)
        right += Array(repeating: "0", count: count - right.count)
        for (leftPart, rightPart) in zip(left, right) {
            let result = leftPart.compare(rightPart, options: .numeric)
            if result != .orderedSame {
                return result
            }
        }
        return .orderedSame
    }
}
