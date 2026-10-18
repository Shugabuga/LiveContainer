//
//  HomeMetrics.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Where everything on the Home Screen goes on the current screen, in points
/// from the screen's top left corner. HomeDesign's measurements are scaled
/// from the screen's width, and the rows share the height between the status
/// bar and the search pill, so the layout matches a real Home Screen on an
/// iPhone 13 Pro Max and keeps its proportions elsewhere. In landscape the
/// grid turns to 6 columns by 4 rows and the dock stands on the trailing side,
/// as on iPhones whose Home Screen rotates.
struct HomeMetrics: Equatable {
    /// The size of the whole screen.
    let size: CGSize
    /// The factor HomeDesign's sizes are multiplied by.
    let scale: Double
    /// How many columns a page has.
    let columns: Int
    /// How many rows a page has.
    let rows: Int
    /// An icon's width and height.
    let iconSize: Double
    /// An icon's corner radius.
    let iconCornerRadius: Double
    /// The width an icon's name can use.
    let cellWidth: Double
    /// The height of an icon with its name under it.
    let cellHeight: Double
    /// The dock's frame.
    let dockFrame: CGRect
    /// Whether the dock stands on the trailing side, in landscape.
    let isDockVertical: Bool
    /// The dock's corner radius where corners can't follow the screen's.
    let dockCornerRadius: Double
    /// The center of the search pill and the page dots.
    let pillCenter: CGPoint
    /// The vertical center of the buttons edit mode shows in place of the
    /// status bar.
    let editControlsCenterY: Double
    /// The space between the edit mode buttons and the sides of the screen.
    let editControlsInset: Double

    /// The center of the first icon on a page.
    private let firstIconCenter: CGPoint
    /// The distance between neighboring columns and rows.
    private let pitch: CGSize
    /// The distance between neighboring icons in the dock.
    private let dockPitch: Double

    /// Lays the Home Screen out for a screen of `size`, whose system bars
    /// cover `safeArea`.
    init(size: CGSize, safeArea: EdgeInsets) {
        self.size = size
        let labelBlock = HomeDesign.labelSpacing + HomeDesign.labelLineHeight
        isDockVertical = size.width > size.height
        editControlsCenterY = max(safeArea.top * 0.54, 24)

        if isDockVertical {
            let scale = min(size.height / HomeDesign.referenceWidth, HomeDesign.maximumScale)
            self.scale = scale
            columns = 6
            rows = 4
            let edge = HomeDesign.dockBottomInset * scale
            let thickness = HomeDesign.dockThickness * scale
            dockFrame = CGRect(
                x: size.width - max(safeArea.trailing, edge) - thickness,
                y: edge,
                width: thickness,
                height: size.height - edge * 2
            )
            let left = max(safeArea.leading, 16 * scale) + 8 * scale
            let right = dockFrame.minX - 8 * scale
            let top = max(safeArea.top, 8 * scale) + 6 * scale
            pillCenter = CGPoint(
                x: (left + right) / 2,
                y: size.height - max(safeArea.bottom, 8 * scale) - HomeDesign.pillHeight / 2 - 2 * scale
            )
            let bottom = pillCenter.y - HomeDesign.pillHeight / 2 - 4 * scale
            pitch = CGSize(width: (right - left) / 6, height: (bottom - top) / 4)
            iconSize = max(min(HomeDesign.iconSize * scale, pitch.height - labelBlock - 2, pitch.width - 12), 20)
            firstIconCenter = CGPoint(
                x: left + pitch.width / 2,
                y: top + (pitch.height - iconSize - labelBlock) / 2 + iconSize / 2
            )
            dockPitch = min(HomeDesign.columnPitch * scale, (dockFrame.height - 24 * scale) / 4)
            editControlsInset = max(safeArea.leading, safeArea.trailing) + 16
        } else {
            let scale = min(size.width / HomeDesign.referenceWidth, HomeDesign.maximumScale)
            self.scale = scale
            columns = 4
            rows = 6
            let dockWidth = (HomeDesign.referenceWidth - HomeDesign.dockSideInset * 2) * scale
            let thickness = HomeDesign.dockThickness * scale
            dockFrame = CGRect(
                x: (size.width - dockWidth) / 2,
                y: size.height - HomeDesign.dockBottomInset * scale - thickness,
                width: dockWidth,
                height: thickness
            )
            pillCenter = CGPoint(x: size.width / 2, y: dockFrame.minY - HomeDesign.pillAboveDock * scale)
            // At least the status bar's height, so the icons stay put when edit
            // mode hides the status bar on iPhones with a Home button.
            let firstIconTop = max(safeArea.top, 20) + HomeDesign.firstRowBelowStatusBar * scale
            let pillTop = pillCenter.y - HomeDesign.pillHeight / 2
            let rowPitch = (pillTop - firstIconTop) / HomeDesign.rowsAbovePill
            pitch = CGSize(width: HomeDesign.columnPitch * scale, height: rowPitch)
            iconSize = max(min(HomeDesign.iconSize * scale, rowPitch - labelBlock - 2), 20)
            firstIconCenter = CGPoint(
                x: size.width / 2 - pitch.width * 1.5,
                y: firstIconTop + iconSize / 2
            )
            dockPitch = pitch.width
            editControlsInset = 16
        }

        iconCornerRadius = iconSize * HomeDesign.iconCornerFraction
        cellWidth = max(pitch.width - 6, iconSize)
        cellHeight = iconSize + labelBlock
        dockCornerRadius = HomeDesign.dockCornerRadius * scale
    }

    /// The layout of the iPhone 13 Pro Max in portrait, the screen HomeDesign
    /// was measured on, for views that show icons before the screen's size is known.
    static let reference = HomeMetrics(
        size: CGSize(width: 428, height: 926),
        safeArea: EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0)
    )

    /// How many icons a page holds.
    var iconsPerPage: Int {
        columns * rows
    }

    /// The center of the icon at `index` on a page, on screen.
    func iconCenter(at index: Int) -> CGPoint {
        let column = index % columns
        let row = index / columns
        return CGPoint(
            x: firstIconCenter.x + Double(column) * pitch.width,
            y: firstIconCenter.y + Double(row) * pitch.height
        )
    }

    /// The center of the icon and its name together, which is where the view
    /// holding both goes for the icon at `index` on a page.
    func cellCenter(at index: Int) -> CGPoint {
        let icon = iconCenter(at: index)
        return CGPoint(x: icon.x, y: icon.y - iconSize / 2 + cellHeight / 2)
    }

    /// The center of the icon at `index` in a dock holding `count` icons,
    /// which keeps its icons centered as iOS does.
    func dockIconCenter(at index: Int, count: Int) -> CGPoint {
        let offset = (Double(index) - Double(max(count, 1) - 1) / 2) * dockPitch
        if isDockVertical {
            return CGPoint(x: dockFrame.midX, y: dockFrame.midY + offset)
        }
        return CGPoint(x: dockFrame.midX + offset, y: dockFrame.midY)
    }

    /// An icon's frame, around its center.
    func iconFrame(around center: CGPoint) -> CGRect {
        CGRect(x: center.x - iconSize / 2, y: center.y - iconSize / 2, width: iconSize, height: iconSize)
    }

    /// The position on a page nearest to a point on screen.
    func gridIndex(nearest point: CGPoint) -> Int {
        let column = Self.steps(point.x - firstIconCenter.x, of: pitch.width)
        let row = Self.steps(point.y - firstIconCenter.y, of: pitch.height)
        return min(max(row, 0), rows - 1) * columns + min(max(column, 0), columns - 1)
    }

    /// Where an icon dropped at a point goes in a dock that holds `count`
    /// other icons: before the icon it lands on, or at either end.
    func dockIndex(nearest point: CGPoint, count: Int) -> Int {
        let first = dockIconCenter(at: 0, count: count + 1)
        let distance = isDockVertical ? point.y - first.y : point.x - first.x
        return min(max(Self.steps(distance, of: dockPitch), 0), count)
    }

    /// How many whole steps of `step` points fit in `distance`, rounded, or 0
    /// before the screen has a size.
    private static func steps(_ distance: Double, of step: Double) -> Int {
        guard step > 0, distance.isFinite else {
            return 0
        }
        return Int((distance / step).rounded())
    }

    /// Whether a point is over the dock, with a little room around it.
    func dockContains(_ point: CGPoint) -> Bool {
        dockFrame.insetBy(dx: -8, dy: -8).contains(point)
    }
}
