//
//  ZeusDiscordRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The row that opens Zeus's Discord server, on Settings > Zeus and at the
/// end of onboarding: Discord's logo as big as the icons of the other rows,
/// "Discord" and a line inviting people in, with an arrow on the trailing
/// side, like the Settings app's links out. The invite opens in Discord when
/// it's installed, or else in the browser, which VoiceOver's hint says.
struct ZeusDiscordRow: View {
    /// Discord's logo. Built without Xcode, zContainer has no Assets.car and
    /// the logo is a loose PNG in the app bundle; UIImage finds it either way.
    private let logo = UIImage(named: "Discord")

    @ScaledMetric(relativeTo: .body) private var size = SettingsDesign.iconSize

    var body: some View {
        // The colors are fixed ones rather than .primary and .secondary, which
        // a link takes from the tint, so the row reads like the rows around it
        // while still highlighting as a whole when tapped.
        Link(destination: ZeusCommunity.discordURL) {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: SettingsDesign.subtitleSpacing) {
                        // A name, the same in every language.
                        Text(verbatim: "Discord")
                            .foregroundStyle(Color.primary)

                        Text("zc.settings.zeus.discordDetail".loc)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                } icon: {
                    Image(uiImage: logo ?? UIImage())
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                        .frame(width: logoSize, height: logoSize)
                        .clipShape(.rect(cornerRadius: logoSize * SettingsDesign.iconCornerRatio))
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint("zc.settings.zeus.discordHint".loc)
    }

    /// The logo's side: as big as the other rows' icons, growing with the
    /// text size until the 180-pixel logo would start to blur.
    private var logoSize: Double {
        min(size, SettingsDesign.largestLogoSize)
    }
}
