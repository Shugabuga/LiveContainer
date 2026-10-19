//
//  ZeusHeader.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The top of the Zeus page, like the top of the Apple Account page: Zeus's
/// icon, large, then "Zeus" and what Zeus does for zContainer, centered.
struct ZeusHeader: View {
    var body: some View {
        VStack(spacing: SettingsDesign.headerSpacing) {
            ZeusMark(size: SettingsDesign.headerMarkSize)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            Text("zc.settings.zeus".loc)
                .font(.title)
                .bold()

            Text("zc.settings.zeus.headerDetail".loc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
