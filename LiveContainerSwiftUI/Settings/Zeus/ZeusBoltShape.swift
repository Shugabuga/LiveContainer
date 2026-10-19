//
//  ZeusBoltShape.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Zeus's bolt, the mark on Zeus's app icon, drawn from the outline of Zeus's
/// logo. It keeps its proportions and sits in the middle of the space given.
struct ZeusBoltShape: Shape {
    /// The size of the box the outline below is drawn in.
    private static let canvas = CGSize(width: 52, height: 52.8)

    /// The corners of the bolt, clockwise from the top of its upper stroke.
    private static let outline: [CGPoint] = [
        CGPoint(x: 22.8365, y: 0),
        CGPoint(x: 22.8363, y: 17.599),
        CGPoint(x: 28.669, y: 17.599),
        CGPoint(x: 28.669, y: 14.164),
        CGPoint(x: 28.6696, y: 14.1646),
        CGPoint(x: 37.9198, y: 23.4664),
        CGPoint(x: 0, y: 23.4664),
        CGPoint(x: 28.6696, y: 52.8),
        CGPoint(x: 28.669, y: 35.1991),
        CGPoint(x: 22.8363, y: 35.1991),
        CGPoint(x: 22.8363, y: 38.5337),
        CGPoint(x: 13.8397, y: 29.3315),
        CGPoint(x: 52, y: 29.3315),
    ]

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.canvas.width, rect.height / Self.canvas.height)
        let origin = CGPoint(
            x: rect.midX - Self.canvas.width * scale / 2,
            y: rect.midY - Self.canvas.height * scale / 2
        )
        var path = Path()
        path.addLines(Self.outline.map { point in
            CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
        })
        path.closeSubpath()
        return path
    }
}
