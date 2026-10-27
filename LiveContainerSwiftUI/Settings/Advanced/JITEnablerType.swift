//
//  JITEnablerType.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The tool that enables JIT for apps that need it, which Settings > Advanced
/// > JIT chooses: Zeus unless another was chosen. The raw values are saved as
/// LCJITEnablerType in the app group's defaults, so they never change.
enum JITEnablerType: Int, CaseIterable, Identifiable {
    /// Zeus, which starts zContainer with JIT through the iPhone's own
    /// services, as it starts its own apps with JIT, with nothing else to
    /// install.
    case Zeus = 7
    case SideJITServer = 0
    case StikJIT = 1
    case JITStreamerEBLegacy = 2
    case StikJITLC = 3
    case StosDebug = 5
    case StosDebugLC = 6

    var id: Int {
        rawValue
    }

    /// The tool set in Settings, or Zeus when none was chosen.
    static var current: JITEnablerType {
        let defaults = LCUtils.appGroupUserDefault
        guard defaults.object(forKey: storageKey) != nil else {
            return .Zeus
        }
        return JITEnablerType(rawValue: defaults.integer(forKey: storageKey)) ?? .Zeus
    }

    /// The app group defaults key the choice is saved under.
    static let storageKey = "LCJITEnablerType"

    /// The tool's name.
    var displayName: String {
        switch self {
        case .Zeus: "Zeus"
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
