//
//  ZeusCheckStatus.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// How one part of the setup stands, on the trailing side of its row: a
/// spinner while Check Setup looks at it, then a check, an exclamation mark
/// for an optional part that's missing, or a cross. Each has its own symbol
/// as well as its color, and VoiceOver reads what it means.
struct ZeusCheckStatus: View {
    let result: ZeusCheckResult

    var body: some View {
        switch result {
        case .notChecked:
            Text("zc.settings.setup.notChecked".loc)
                .foregroundStyle(.secondary)
        case .checking:
            ProgressView()
                .accessibilityLabel("lc.jitlessDiag.checking".loc)
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.green)
                .accessibilityLabel("zc.settings.setup.passed".loc)
        case .missing:
            Image(systemName: "exclamationmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.orange)
                .accessibilityLabel("zc.settings.setup.missing".loc)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.red)
                .accessibilityLabel("zc.settings.setup.failed".loc)
        }
    }
}
