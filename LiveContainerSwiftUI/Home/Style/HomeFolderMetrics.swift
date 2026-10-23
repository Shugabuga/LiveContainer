//
//  HomeFolderMetrics.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Where things go in an open folder, measured from iOS 27's on an iPhone: a
/// glass panel in the middle of the screen holding three rows of three
/// icons, at the Home Screen's icon size and spacing, as far in from the
/// panel's edges as the icons are apart, with the folder's name in large
/// type above it, lined up with the first column.
struct HomeFolderMetrics: Equatable {
    /// The panel the icons sit in, on screen.
    let panel: CGRect
    /// The panel's corner radius: half an icon, as on iOS.
    let cornerRadius: Double
    /// The size of an icon, and of an icon with its name under it.
    let iconSize: Double
    let cellHeight: Double
    /// The distance between neighboring columns and rows.
    let pitch: CGSize
    /// The distance from the panel's edges to its first icons.
    let inset: Double

    init(_ metrics: HomeMetrics) {
        iconSize = metrics.iconSize
        cellHeight = metrics.cellHeight
        pitch = metrics.pitch
        inset = max(metrics.pitch.width - metrics.iconSize, 0)
        cornerRadius = metrics.iconSize / 2
        let columns = Double(HomeFolderMetrics.columns)
        let width = 2 * inset + (columns - 1) * pitch.width + iconSize
        let height = 2 * inset + (columns - 1) * pitch.height + cellHeight
        panel = CGRect(
            x: (metrics.size.width - width) / 2,
            y: (metrics.size.height - height) / 2,
            width: width,
            height: height
        )
    }

    /// How many icons a row of a folder's page holds, and how many rows.
    static let columns = 3

    /// The center of the icon at a position on the folder's page showing, on
    /// screen.
    func iconCenter(at index: Int) -> CGPoint {
        let local = localIconCenter(at: index)
        return CGPoint(x: panel.minX + local.x, y: panel.minY + local.y)
    }

    /// The center of the icon at a position on a page, from the page's top
    /// left corner.
    func localIconCenter(at index: Int) -> CGPoint {
        let column = index % Self.columns
        let row = index / Self.columns
        return CGPoint(
            x: inset + iconSize / 2 + Double(column) * pitch.width,
            y: inset + iconSize / 2 + Double(row) * pitch.height
        )
    }

    /// The center of an icon with its name, which is where the view holding
    /// both goes, at a position on a page, from the page's top left corner.
    func localCellCenter(at index: Int) -> CGPoint {
        let icon = localIconCenter(at: index)
        return CGPoint(x: icon.x, y: icon.y - iconSize / 2 + cellHeight / 2)
    }

    /// The position on the page showing nearest to a point on screen.
    func index(nearest point: CGPoint) -> Int {
        let first = iconCenter(at: 0)
        let column = Int(((point.x - first.x) / pitch.width).rounded())
        let row = Int(((point.y - first.y) / pitch.height).rounded())
        let last = Self.columns - 1
        return min(max(row, 0), last) * Self.columns + min(max(column, 0), last)
    }

    /// Whether a dragged icon held at `point` is still over the folder: over
    /// the panel, or close to it.
    func holds(_ point: CGPoint) -> Bool {
        panel.insetBy(dx: -HomeDesign.folderDragMargin, dy: -HomeDesign.folderDragMargin).contains(point)
    }

    /// Where the folder's name goes: lined up with the first column, a little
    /// before it as large type's own spacing puts it, with its baseline the
    /// title's gap above the panel.
    var titleLeading: Double {
        panel.minX + inset - HomeDesign.folderTitleOverhang
    }

    var titleBaseline: Double {
        panel.minY - HomeDesign.folderTitleGap
    }
}
