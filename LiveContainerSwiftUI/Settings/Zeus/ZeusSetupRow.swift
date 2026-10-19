//
//  ZeusSetupRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One part of the setup in Check Setup's list: its icon, its name, what it
/// does (or, when it failed, why, in red), and how it stands.
struct ZeusSetupRow: View {
    let check: ZeusSetupCheck
    let result: ZeusCheckResult

    var body: some View {
        LabeledContent {
            ZeusCheckStatus(result: result)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: SettingsDesign.subtitleSpacing) {
                    Text(check.title)

                    Text(result.failure ?? check.detail)
                        .font(.footnote)
                        .foregroundStyle(result.failure == nil ? Color.secondary : Color.red)
                }
            } icon: {
                SettingsIcon(systemImage: check.systemImage, color: check.color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
