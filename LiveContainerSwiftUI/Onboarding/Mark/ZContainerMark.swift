//
//  ZContainerMark.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's icon, drawn rather than loaded so it stays sharp at any size
/// and its parts can arrive one by one: the pink container and z on their
/// near black tile, with a hairline around the tile so it doesn't melt into
/// a dark page.
struct ZContainerMark: View {
    /// How much of the icon shows.
    var stage = ZContainerMarkStage.letter
    /// The icon's width and height.
    var size = OnboardingDesign.markSize

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: size * OnboardingDesign.iconCornerRatio)

        ZStack {
            tile
                .fill(OnboardingDesign.markTile)
                .overlay {
                    tile.strokeBorder(.separator, lineWidth: OnboardingDesign.markOutlineWidth)
                }
                .scaleEffect(stage >= .tile ? 1 : 0.8)
                .opacity(stage >= .tile ? 1 : 0)

            ZContainerMarkFrame()
                .trim(from: 0, to: stage >= .frame ? 1 : 0)
                .stroke(
                    OnboardingDesign.accent,
                    style: StrokeStyle(lineWidth: size * ZContainerMarkFrame.lineWidthRatio, lineCap: .round, lineJoin: .round)
                )

            ZContainerMarkLetter()
                .fill(OnboardingDesign.accent)
                .scaleEffect(stage >= .letter ? 1 : 0.4)
                .opacity(stage >= .letter ? 1 : 0)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
