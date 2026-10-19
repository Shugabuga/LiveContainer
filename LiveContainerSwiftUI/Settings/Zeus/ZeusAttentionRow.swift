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
    /// Whether the row draws the chevron of a row that opens a page, for a
    /// button that opens one itself. A navigation link's row gets it from
    /// the list.
    var showsChevron = false

    var body: some View {
        LabeledContent {
            HStack {
                SettingsBadge(count: 1)
                    .accessibilityHidden(true)

                if showsChevron {
                    // The weight of the chevron the list draws on rows that open a page.
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        } label: {
            Text(attention.title)
                .foregroundStyle(.primary)
        }
        .contentShape(.rect)
    }
}
