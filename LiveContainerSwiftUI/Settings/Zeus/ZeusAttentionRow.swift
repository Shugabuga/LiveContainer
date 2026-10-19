//
//  ZeusAttentionRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The row under the Zeus card when zContainer can't sign apps, like "Finish
/// Setting Up Your iPhone" under the Apple Account in the Settings app: what
/// is wrong, and a red badge with a 1.
struct ZeusAttentionRow: View {
    /// What is wrong.
    let attention: ZeusAttention

    var body: some View {
        LabeledContent {
            SettingsBadge(count: 1)
                .accessibilityHidden(true)
        } label: {
            Text(attention.title)
        }
    }
}
