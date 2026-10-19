//
//  ZContainerMarkLetter.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The z in zContainer's icon, with a 45 degree diagonal like Zeus's mark,
/// traced from `Scripts/zc/art/AppIcon.svg` (1024 points across). Its middle
/// is the icon's middle, so it can grow out of it.
struct ZContainerMarkLetter: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 1024
        let origin = CGPoint(x: rect.midX - 512 * unit, y: rect.midY - 512 * unit)
        let points: [(Double, Double)] = [
            (457.3, 328), (666.7, 328), (666.7, 428), (498.7, 596), (666.7, 596),
            (566.7, 696), (357.3, 696), (357.3, 596), (525.3, 428), (357.3, 428),
        ]

        var path = Path()
        path.addLines(points.map { x, y in
            CGPoint(x: origin.x + x * unit, y: origin.y + y * unit)
        })
        path.closeSubpath()
        return path
    }
}
