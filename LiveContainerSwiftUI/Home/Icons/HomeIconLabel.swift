//
//  HomeIconLabel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An icon's name under it: one line in white, cut short with an ellipsis when
/// it doesn't fit. Like iOS, the Home Screen keeps names at one size whatever
/// the text size setting, so they always fit their column.
struct HomeIconLabel: View {
    /// The name, shown as it is.
    let title: String

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: HomeDesign.labelFontSize))
            .foregroundStyle(HomeDesign.labelColor)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
