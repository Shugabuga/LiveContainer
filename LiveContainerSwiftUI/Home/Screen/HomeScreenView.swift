//
//  HomeScreenView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's main screen: a Home Screen like the iPhone's, on a black
/// wallpaper under the real status bar. It shows the apps inside zContainer on
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
            // as on iOS, so it reads the whole screen's size and safe area.
            GeometryReader { proxy in
                HomeSpringboard(
                    metrics: HomeMetrics(size: proxy.size, safeArea: proxy.safeAreaInsets, isPhone: isPhone),
                    zoomNamespace: zoomNamespace
                )
            }
            .ignoresSafeArea()
            .blur(radius: model.isSearching ? HomeDesign.searchBlur : 0)
            // Search covers the Home Screen for touches and for VoiceOver alike.
            .allowsHitTesting(!model.isSearching)
            .accessibilityHidden(model.isSearching)

            if model.isSearching {
                HomeSearchView()
                    .transition(.opacity)
            }
        }
        .background(Color.black)
        // The Home Screen is drawn for its black wallpaper, whatever the
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

    /// Whether zContainer runs on an iPhone, whose Home Screen has its own
    /// layout when the iPhone has a Home button. SwiftUI has no way to tell
    /// an iPhone from an iPad by itself.
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}
