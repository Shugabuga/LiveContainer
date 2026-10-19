//
//  ZeusHeader.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The top of the Zeus page, like the top of the Apple Account page but
/// smaller: Zeus's icon, then "Zeus" and a line on what it does for
/// zContainer, centered.
struct ZeusHeader: View {
    var body: some View {
        VStack(spacing: SettingsDesign.headerSpacing) {
            ZeusMark(size: SettingsDesign.headerMarkSize)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            VStack(spacing: SettingsDesign.subtitleSpacing) {
                Text("zc.settings.zeus".loc)
                    .font(.title2)
                    .bold()

                Text("zc.settings.zeus.headerDetail".loc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
