//
//  ZContainerMarkFrame.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The container in zContainer's icon: an app-shaped outline with continuous
/// corners, traced from `Scripts/zc/art/AppIcon.svg` (1024 points across).
/// Stroke it `lineWidthRatio` of the icon's size thick. It starts near the
/// top left corner and runs clockwise, so trimming it draws it around.
struct ZContainerMarkFrame: Shape {
    /// How thick the outline is, for the icon's size: 44 of its 1024 points.
    static let lineWidthRatio = 44.0 / 1024

    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 1024
        let origin = CGPoint(x: rect.midX - 512 * unit, y: rect.midY - 512 * unit)
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: origin.x + x * unit, y: origin.y + y * unit)
        }

        var path = Path()
        path.move(to: point(411.3, 182))
        path.addLine(to: point(612.7, 182))
        path.addCurve(to: point(747.3, 193.2), control1: point(678.7, 182), control2: point(711.7, 182))
        path.addCurve(to: point(830.8, 276.7), control1: point(786.1, 207.4), control2: point(816.6, 237.9))
        path.addCurve(to: point(842, 411.3), control1: point(842, 312.3), control2: point(842, 345.3))
        path.addLine(to: point(842, 612.7))
        path.addCurve(to: point(830.8, 747.3), control1: point(842, 678.7), control2: point(842, 711.7))
        path.addCurve(to: point(747.3, 830.8), control1: point(816.6, 786.1), control2: point(786.1, 816.6))
        path.addCurve(to: point(612.7, 842), control1: point(711.7, 842), control2: point(678.7, 842))
        path.addLine(to: point(411.3, 842))
        path.addCurve(to: point(276.7, 830.8), control1: point(345.3, 842), control2: point(312.3, 842))
        path.addCurve(to: point(193.2, 747.3), control1: point(237.9, 816.6), control2: point(207.4, 786.1))
        path.addCurve(to: point(182, 612.7), control1: point(182, 711.7), control2: point(182, 678.7))
        path.addLine(to: point(182, 411.3))
        path.addCurve(to: point(193.2, 276.7), control1: point(182, 345.3), control2: point(182, 312.3))
        path.addCurve(to: point(276.7, 193.2), control1: point(207.4, 237.9), control2: point(237.9, 207.4))
        path.addCurve(to: point(411.3, 182), control1: point(312.3, 182), control2: point(345.3, 182))
        path.closeSubpath()
        return path
    }
}
