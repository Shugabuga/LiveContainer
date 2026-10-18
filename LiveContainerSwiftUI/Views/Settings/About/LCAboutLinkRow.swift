//
//  LCAboutLinkRow.swift
//  LiveContainerSwiftUI
//
//  A row of the About page that opens a web page.
//

import SwiftUI

struct LCAboutLinkRow: View {
    /// Already localized, or a name that isn't translated.
    let title: String
    let detail: String?
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
}
