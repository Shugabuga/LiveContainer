//
//  ZeusMark.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Zeus's icon as Settings shows it: the pink bolt on its near black tile,
/// in the shape of an app icon. It grows with the text size; the places that
/// show it stop that at the largest standard size, so large text gets the
/// room beside it.
struct ZeusMark: View {
    @ScaledMetric private var size: Double

    /// - Parameter size: The tile's width and height at the default text size.
    init(size: Double) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .title2)
    }

    var body: some View {
        ZeusBoltShape()
            .fill(SettingsDesign.zeusPink)
            .frame(width: size * SettingsDesign.boltRatio, height: size * SettingsDesign.boltRatio)
            .frame(width: size, height: size)
            .background(SettingsDesign.zeusTile, in: .rect(cornerRadius: size * SettingsDesign.iconCornerRatio))
            .overlay {
                RoundedRectangle(cornerRadius: size * SettingsDesign.iconCornerRatio)
                    .strokeBorder(.separator, lineWidth: SettingsDesign.iconOutlineWidth)
            }
            .accessibilityHidden(true)
    }
}
