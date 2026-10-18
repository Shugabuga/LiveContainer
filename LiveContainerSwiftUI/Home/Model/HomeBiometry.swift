//
//  HomeBiometry.swift
//  LiveContainerSwiftUI
//

import LocalAuthentication

/// How this iPhone unlocks a locked app, which names the lock actions the way
/// iOS does: "Require Face ID", "Require Touch ID", or the passcode.
enum HomeBiometry {
    case faceID
    case touchID
    case passcode

    /// The kind this device has, checked once.
    static let current: HomeBiometry = {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .passcode
        }
        return switch context.biometryType {
        case .faceID:
            .faceID
        case .touchID:
            .touchID
        default:
            .passcode
        }
    }()

    /// The action that locks an app.
    var requireTitle: String {
        switch self {
        case .faceID:
            "zc.home.requireFaceID".loc
        case .touchID:
            "zc.home.requireTouchID".loc
        case .passcode:
            "zc.home.requirePasscode".loc
        }
    }

    /// The action that unlocks a locked app.
    var dontRequireTitle: String {
        switch self {
        case .faceID:
            "zc.home.dontRequireFaceID".loc
        case .touchID:
            "zc.home.dontRequireTouchID".loc
        case .passcode:
            "zc.home.dontRequirePasscode".loc
        }
    }

    /// The action that locks an app and takes it off the Home Screen.
    var hideTitle: String {
        switch self {
        case .faceID:
            "zc.home.hideAndRequireFaceID".loc
        case .touchID:
            "zc.home.hideAndRequireTouchID".loc
        case .passcode:
            "zc.home.hideAndRequirePasscode".loc
        }
    }

    /// The symbol shown with the lock actions.
    var systemImage: String {
        switch self {
        case .faceID:
            "faceid"
        case .touchID:
            "touchid"
        case .passcode:
            "lock"
        }
    }
}
