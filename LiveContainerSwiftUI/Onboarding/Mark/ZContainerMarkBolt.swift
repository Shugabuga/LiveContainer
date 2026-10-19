//
//  ZContainerMarkBolt.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Zeus's bolt inside zContainer's icon, traced from
/// `Scripts/zc/art/AppIcon.svg` (1024 points across), which draws it from
/// Zeus's logo. Its middle is the icon's middle, so it can grow out of it.
struct ZContainerMarkBolt: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 1024
        let origin = CGPoint(x: rect.midX - 512 * unit, y: rect.midY - 512 * unit)
        let points: [(Double, Double)] = [
            (486.8, 302), (486.8, 442), (533.2, 442), (533.2, 414.7), (606.8, 488.7),
            (305.2, 488.7), (533.2, 722), (533.2, 582), (486.8, 582), (486.8, 608.5),
            (415.3, 535.3), (718.8, 535.3),
        ]

        var path = Path()
        path.addLines(points.map { x, y in
            CGPoint(x: origin.x + x * unit, y: origin.y + y * unit)
        })
        path.closeSubpath()
        return path
    }
}
