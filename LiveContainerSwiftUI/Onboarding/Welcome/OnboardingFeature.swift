//
//  OnboardingFeature.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What zContainer does, in the order the welcome screen lists it.
enum OnboardingFeature: Int, CaseIterable, Identifiable {
    case oneSlot
    case signedByZeus
    case homeScreen

    var id: Self { self }

    /// The SF Symbol on the feature's icon.
    var systemImage: String {
        switch self {
        case .oneSlot: "square.grid.2x2.fill"
        case .signedByZeus: "bolt.fill"
        case .homeScreen: String.homeScreenSymbol
        }
    }

    var title: String {
        switch self {
        case .oneSlot: "zc.onboarding.feature.oneSlot".loc
        case .signedByZeus: "zc.onboarding.feature.signedByZeus".loc
        case .homeScreen: "zc.onboarding.feature.homeScreen".loc
        }
    }

    var message: String {
        switch self {
        case .oneSlot: "zc.onboarding.feature.oneSlotDetail".loc
        case .signedByZeus: "zc.onboarding.feature.signedByZeusDetail".loc
        case .homeScreen: "zc.onboarding.feature.homeScreenDetail".deviceLoc
        }
    }
}
