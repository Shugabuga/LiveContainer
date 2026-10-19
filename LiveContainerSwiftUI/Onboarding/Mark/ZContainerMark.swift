//
//  ZContainerMark.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's icon, drawn rather than loaded so it stays sharp at any size
/// and its parts can arrive one by one: the pink container and z on their
/// near black tile, with a hairline around the tile so it doesn't melt into
/// a dark page. Each part swells in, and the outline draws itself around,
/// except with Reduce Motion, where every part is whole from the start and
/// only fades in.
struct ZContainerMark: View {
    /// How much of the icon shows.
    var stage = ZContainerMarkStage.letter
    /// The icon's width and height.
    var size = OnboardingDesign.markSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: size * OnboardingDesign.iconCornerRatio)

        ZStack {
            tile
                .fill(OnboardingDesign.markTile)
                .overlay {
                    tile.strokeBorder(.separator, lineWidth: OnboardingDesign.markOutlineWidth)
                }
                .scaleEffect(scale(of: .tile, from: 0.8))
                .opacity(stage >= .tile ? 1 : 0)

            ZContainerMarkFrame()
                .trim(from: 0, to: reduceMotion || stage >= .frame ? 1 : 0)
                .stroke(
                    OnboardingDesign.accent,
                    style: StrokeStyle(lineWidth: size * ZContainerMarkFrame.lineWidthRatio, lineCap: .round, lineJoin: .round)
                )
                .opacity(reduceMotion && stage < .frame ? 0 : 1)

            ZContainerMarkLetter()
                .fill(OnboardingDesign.accent)
                .scaleEffect(scale(of: .letter, from: 0.4))
                .opacity(stage >= .letter ? 1 : 0)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// How big a part is: full size once its stage has come, and until then
    /// `start`, which it swells from. With Reduce Motion it's always full
    /// size.
    private func scale(of part: ZContainerMarkStage, from start: Double) -> Double {
        reduceMotion || stage >= part ? 1 : start
    }
}
