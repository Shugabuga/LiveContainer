//
//  HomeDesign.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home Screen's look in one place. Sizes are in points, measured on an
/// iPhone 13 Pro Max running iOS 27 (428 by 926 points); HomeMetrics scales
/// them to the screen in use.
enum HomeDesign {
    // MARK: Reference screen

    /// The width the sizes below were measured at.
    static let referenceWidth = 428.0
    /// The largest scale HomeMetrics applies, so an iPad's icons come out a
    /// little larger than an iPhone's instead of giant.
    static let maximumScale = 1.2
    /// The coordinate space of the whole screen, which HomeMetrics' positions
    /// and the drag gesture share.
    static let coordinateSpace = "HomeScreen"

    // MARK: Icons

    /// An icon's width and height.
    static let iconSize = 68.0
    /// An icon's corner radius as a fraction of its size, the Home Screen
    /// icon shape.
    static let iconCornerFraction = 0.225
    /// The distance between the centers of neighboring columns.
    static let columnPitch = 98.6
    /// How far the grid sits right of the screen's center on a real Home
    /// Screen, which isn't quite centered. The dock is.
    static let gridOffsetX = 1.85
    /// How far the first row's icons start below the status bar.
    static let firstRowBelowStatusBar = 24.8
    /// The distance from the first row's top to the search pill's top, in
    /// rows: the grid fills that space, so smaller screens get tighter rows.
    static let rowsAbovePill = 6.383
    /// The space between an icon and its name.
    static let labelSpacing = 5.0
    /// The size of an icon's name. The Home Screen keeps names at this size
    /// whatever the text size setting, as iOS does.
    static let labelFontSize = 12.0
    /// The weight of an icon's name, a little heavier than regular, as on iOS.
    static let labelWeight = Font.Weight.medium
    /// The height of a name's line.
    static let labelLineHeight = 14.3
    /// The color of the names, readable on the black wallpaper.
    static let labelColor = Color.white
    /// The soft shadow under the names over a photo, so they read over its
    /// bright parts, as on iOS.
    static let labelShadow = Color.black.opacity(0.45)
    /// How far the names' shadow spreads.
    static let labelShadowRadius = 2.0

    // MARK: iPhones with a Home button

    // These iPhones have square screen corners and nothing under the screen's
    // bottom edge, so iOS lays their Home Screen out with fixed sizes rather
    // than scaling the Face ID layout: the 4.7 inch grid of 60 point icons
    // 87 points apart, and a full-width dock along the bottom.

    /// An icon's width and height.
    static let squareScreenIconSize = 60.0
    /// The distance between the centers of neighboring columns, which leaves
    /// 27 points at each side of a 375 point screen.
    static let squareScreenColumnPitch = 87.0
    /// The most the rows can be apart, the distance on the 4.7 inch grid.
    /// They come closer when the search pill needs the room.
    static let squareScreenMaximumRowPitch = 88.0
    /// How far the first row's icons start below the status bar, which keeps
    /// them clear of edit mode's buttons.
    static let squareScreenFirstRowBelowStatusBar = 20.0
    /// The dock's height. It runs the full width of the screen, flush with
    /// the bottom edge, with square corners.
    static let squareScreenDockHeight = 96.0
    /// The space between the search pill and the dock, and between the
    /// pill and the names of the last row.
    static let squareScreenPillGap = 4.0
    /// The size of edit mode's round add button and the height of Done,
    /// smaller than elsewhere so they fit the short status bar.
    static let squareScreenEditButtonSize = 28.0

    // MARK: iPad

    // iPadOS keeps the dock floating at the bottom in both orientations and
    // spreads the grid over the whole screen, so iPads (and their Split View,
    // Slide Over and Stage Manager windows) get their own layout rather than
    // a scaled up iPhone.

    /// The height HomeDesign's sizes reach full scale at on an iPad, so short
    /// windows scale down as narrow ones do. An iPad mini in landscape (744
    /// points high) still gets full size icons.
    static let padReferenceHeight = 620.0
    /// The space between the grid's outer cells and the sides of the screen,
    /// before scaling. Icons sit centered in their cells, further in.
    static let padGridSideInset = 24.0
    /// The least room between neighboring icons, before scaling. Icons shrink
    /// before they get closer.
    static let padMinimumColumnGap = 16.0
    /// The least room between a name and the icon under it, before scaling.
    static let padMinimumRowGap = 12.0
    /// The most the rows can be apart, as a multiple of the column distance,
    /// so a tall narrow window doesn't pull its rows far apart. The grid
    /// keeps to the top, as a page that isn't full does.
    static let padMaximumRowToColumnPitch = 1.6
    /// How far a name can reach past each side of its icon, before scaling.
    /// iPadOS cuts long names off near their icon rather than letting them
    /// run across the wide columns.
    static let padNameOverhang = 16.0
    /// The space between the ends of the dock's glass and its first and last
    /// icons, before scaling, as on the iPhone's full dock. The glass is only
    /// as wide as its icons need, as on iPadOS.
    static let padDockEndPadding = 17.7
    /// The least room between neighboring icons in the dock, before scaling.
    /// In a window too narrow for a full dock at the pages' icon size, the
    /// dock's icons come this close, then shrink.
    static let padMinimumDockGap = 12.0

    // MARK: Dock

    /// The space between the dock and the sides of the screen.
    static let dockSideInset = 14.4
    /// The dock's height (its width on an iPhone in landscape, where it
    /// stands on the side).
    static let dockThickness = 105.0
    /// The space between the dock and the bottom of the screen.
    static let dockBottomInset = 13.5
    /// The dock's corner radius before iOS 26, where corners can't follow the
    /// screen's. It matches the 13 Pro Max's screen corners less the inset.
    static let dockCornerRadius = 39.0

    // MARK: Wallpaper

    /// How much black goes over a photo wallpaper when it's dimmed, about
    /// what iOS's dark mode dims wallpapers by.
    static let wallpaperDimming = 0.22

    // MARK: Search pill and page dots

    /// How far the search pill's center sits above the dock.
    static let pillAboveDock = 40.2
    /// The search pill's height.
    static let pillHeight = 30.0
    /// The space at each end of the pill.
    static let pillPadding = 12.0
    /// The space between the magnifying glass and "Search".
    static let pillSpacing = 5.0
    /// The size of the pill's text.
    static let pillFontSize = 12.0
    /// The color of the pill's text and glass.
    static let pillTextColor = Color(white: 0.75)
    /// A page dot's size.
    static let pageDotSize = 7.0
    /// The space between page dots.
    static let pageDotSpacing = 8.0
    /// How long the dots stay after the pages stop moving, before "Search"
    /// comes back.
    static let pageDotsLinger = Duration.milliseconds(900)
    /// How far a finger dragged along the page dots moves to go one page
    /// further, a little more than a dot and the space after it.
    static let pageScrubStep = 20.0

    // MARK: Glass

    /// The fill behind the dock and the pill where Liquid Glass isn't
    /// available, the gray the glass shows over a black wallpaper.
    static let fallbackGlassFill = Color(white: 0.067)
    /// The line along the top of a dock that runs to the screen's edges,
    /// where Liquid Glass isn't available.
    static let fallbackGlassHairline = Color(white: 0.3)
    /// The light rim along the glass's edge where Liquid Glass isn't available.
    static let fallbackGlassRim = LinearGradient(
        colors: [Color(white: 0.42), Color(white: 0.12), Color(white: 0.24)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: Editing

    /// How far icons tilt each way while they jiggle, in degrees.
    static let jiggleAngle = 1.4
    /// How long a jiggle takes to tilt one way and back.
    static let jiggleDuration = 0.26
    /// How long an icon must be held in edit mode before it can be dragged,
    /// so a quick swipe still turns the page.
    static let pickUpDelay = 0.15
    /// How much a dragged icon grows.
    static let liftedScale = 1.12
    /// How close to the side of the screen a dragged icon turns the page.
    static let pageTurnEdge = 28.0
    /// How long a dragged icon waits at the side before the page turns.
    static let pageTurnDelay = Duration.milliseconds(550)
    /// How long a dragged icon hovers over a place before the icons move to
    /// make room, so they don't shuffle while it passes over them.
    static let reflowDelay = Duration.milliseconds(110)
    /// The size of the minus badge on icons in edit mode.
    static let minusBadgeSize = 22.0
    /// How far the minus badge's center is from the icon's top left corner.
    static let minusBadgeInset = 3.0

    // MARK: Buttons

    /// The smallest touch area a control gets.
    static let minimumTouchSize = 44.0
    /// The size of edit mode's round add button, and the height of Done.
    static let editButtonSize = 36.0
    /// The space at each end of Done.
    static let editButtonPadding = 18.0

    // MARK: Home button

    /// The Home button's width and height, on zContainer's own screens and
    /// over apps alike (TweakLoader's LCHomeButtonView draws the same button).
    static let homeButtonSize = 52.0
    /// The rings on the Home button, from the outside in: each one's width and
    /// how white it is. They stack like AssistiveTouch's, a soft halo around a
    /// bright dot.
    static let homeButtonRings: [(size: Double, opacity: Double)] = [(40, 0.12), (32, 0.22), (24, 0.92)]
    /// The dark tint of the Home button's glass, so it looks the same over the
    /// black wallpaper, over Settings in light mode and over apps.
    static let homeButtonTint = Color.black.opacity(0.32)
    /// The light rim of the Home button where Liquid Glass isn't available.
    static let homeButtonRim = Color.white.opacity(0.22)
    /// The space above and below the Home button in a screen's bottom bar.
    static let homeButtonBarPadding = 8.0
    /// How much the Home button shrinks while it is pressed.
    static let homeButtonPressedScale = 0.9

    // MARK: Search

    /// How much the Home Screen blurs behind search.
    static let searchBlur = 24.0
    /// How far a pull on the pages must go down to open search.
    static let pullToSearchDistance = 60.0
    /// How long search waits for its field to get the keyboard before it
    /// shows the Home button under the field anyway.
    static let searchFocusWait = Duration.milliseconds(300)
    /// The space between search's panels and the sides of the screen.
    static let searchMargin = 16.0
    /// The space between search's panels, and above the search field.
    static let searchSpacing = 14.0
    /// The height of the search field and of the rows in search's panels.
    static let searchFieldHeight = 48.0
    /// The space inside search's panels.
    static let searchPanelPadding = 16.0
    /// The corner radius of search's panels.
    static let searchPanelCornerRadius = 26.0

    // MARK: Animations

    /// Icons moving to new places.
    static let reflow = Animation.spring(duration: 0.35, bounce: 0.12)
    /// Edit mode, search and the page dots appearing or going away.
    static let modeChange = Animation.spring(duration: 0.3)
    /// A tapped app zooming open before zContainer turns into it.
    static let launchZoom = Animation.easeIn(duration: 0.26)
}
