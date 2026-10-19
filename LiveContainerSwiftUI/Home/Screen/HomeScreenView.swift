//
//  HomeScreenView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's main screen: a Home Screen like the iPhone's, on the halo
/// wallpaper it comes with or a photo chosen for it, under the real status
/// bar. It shows the apps inside zContainer on
/// pages of icons with a dock, opens them with a tap, and opens Settings, an
/// app's settings and search over itself. It is the main window's root, so it
/// also runs HomeRouter's launch checks and links.
struct HomeScreenView: View {
    @Environment(HomeScreenModel.self) private var model
    @Environment(HomeRouter.self) private var router
    @Environment(AppLaunchCoordinator.self) private var coordinator
    @Environment(OnboardingModel.self) private var onboarding
    @Namespace private var zoomNamespace

    var body: some View {
        ZStack {
            // The Home Screen is laid out from the screen's top left corner,
            // as on iOS. A reader that covers the whole screen reads its safe
            // area as empty, so the outer reader stays in the safe area and
            // the insets are where the whole screen sits around it.
            GeometryReader { safeArea in
                GeometryReader { screen in
                    HomeSpringboard(
                        metrics: HomeMetrics(
                            size: screen.size,
                            safeArea: Self.insets(of: safeArea.size, within: screen.frame(in: .named(Self.safeAreaSpace))),
                            isPhone: isPhone
                        ),
                        zoomNamespace: zoomNamespace
                    )
                }
                .ignoresSafeArea()
            }
            .coordinateSpace(.named(Self.safeAreaSpace))
            // Search's keyboard leaves the Home Screen where it is.
            .ignoresSafeArea(.keyboard)
            .blur(radius: model.isSearching ? HomeDesign.searchBlur : 0)
            // Search covers the Home Screen for touches and for VoiceOver alike.
            .allowsHitTesting(!model.isSearching)
            .accessibilityHidden(model.isSearching)

            if model.isSearching {
                HomeSearchView()
                    .transition(.opacity)
            }
        }
        .background {
            HomeWallpaperImage()
        }
        // The Home Screen is drawn for a dark wallpaper, whatever the
        // appearance setting. Screens opened over it keep the setting.
        .environment(\.colorScheme, .dark)
        .homeStatusBarHidden(model.isEditing)
        // A screen over the Home Screen, or onboarding, keeps the setting.
        .preferredColorScheme(model.isCoveredByScreen || onboarding.coversHomeScreen ? nil : .dark)
        .homePresentations(zoomNamespace: zoomNamespace)
        .homeRouting(router, onRoute: model.handle)
        .onReceive(model.appsPublisher, perform: model.syncApps)
        .onChange(of: coordinator.appSettingsCloseRequests) {
            model.closeAppSettings()
        }
    }

    /// The coordinate space of the safe area, which the whole screen is
    /// measured in to find the insets.
    private static let safeAreaSpace = "HomeSafeArea"

    /// The safe area's insets, from its size and the whole screen's frame in
    /// its coordinates, which starts above and before it by the top and
    /// leading insets.
    private static func insets(of safeArea: CGSize, within screen: CGRect) -> EdgeInsets {
        EdgeInsets(
            top: max(-screen.minY, 0),
            leading: max(-screen.minX, 0),
            bottom: max(screen.maxY - safeArea.height, 0),
            trailing: max(screen.maxX - safeArea.width, 0)
        )
    }

    /// Whether zContainer runs on an iPhone, whose Home Screen has its own
    /// layout when the iPhone has a Home button. SwiftUI has no way to tell
    /// an iPhone from an iPad by itself.
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}
