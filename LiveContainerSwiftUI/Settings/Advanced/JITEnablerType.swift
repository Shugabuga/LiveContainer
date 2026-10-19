//
//  JITEnablerType.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The tool that enables JIT for apps that need it, which Settings > Advanced
/// > JIT chooses. The raw values are saved as LCJITEnablerType in the app
/// group's defaults, so they never change.
enum JITEnablerType: Int, CaseIterable, Identifiable {
    case SideJITServer = 0
    case StikJIT = 1
    case JITStreamerEBLegacy = 2
    case StikJITLC = 3
    case StosDebug = 5
    case StosDebugLC = 6

    var id: Int {
        rawValue
    }

    /// The tool's name.
    var displayName: String {
        switch self {
        case .StikJIT: "StikDebug"
        case .StikJITLC: "StikDebug (Another zContainer/Multitask)"
        case .StosDebug: "StosDebug"
        case .StosDebugLC: "StosDebug (Another zContainer/Multitask)"
        case .JITStreamerEBLegacy: "JitStreamer-EB (Relaunch)"
        case .SideJITServer: "SideJITServer/JITStreamer 2.0"
        }
    }

    /// Whether zContainer reaches the tool at an address typed into Settings.
    var needsServerAddress: Bool {
        self == .SideJITServer || self == .JITStreamerEBLegacy
    }

    /// An example of the address the tool listens at, as the address field's
    /// placeholder.
    var addressPlaceholder: String {
        self == .SideJITServer ? "http://x.x.x.x:8080" : "http://[fd00::]:9172"
    }
}
