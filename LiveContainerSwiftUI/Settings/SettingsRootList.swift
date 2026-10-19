//
//  SettingsRootList.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The rows Settings opens on, in the Settings app's order: Zeus on top where
/// the Apple Account is, with a row asking for attention under it when
/// zContainer can't sign apps; then General, Home Screen and Wallpaper; then
/// Apps, which holds each app's settings; and last Advanced, where the
/// Settings app puts Developer. Each row opens a page of its own, except "Finish Setting Up
/// zContainer", which opens onboarding again over the Home Screen.
struct SettingsRootList: View {
    @Environment(ZeusConnection.self) private var connection
    @Environment(OnboardingModel.self) private var onboarding

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ZeusSettingsView()
                } label: {
                    ZeusCard()
                }
            }

            if let attention = connection.attention {
                Section {
                    if attention == .notSetUp {
                        Button(action: onboarding.present) {
                            ZeusAttentionRow(attention: attention, showsChevron: true)
                        }
                    } else {
                        NavigationLink {
                            ZeusSettingsView()
                        } label: {
                            ZeusAttentionRow(attention: attention)
                        }
                    }
                }
            }

            Section {
                NavigationLink {
                    GeneralSettingsView()
                } label: {
                    SettingsRow(title: "zc.settings.general".loc, systemImage: "gear", color: .gray)
                }

                // Its one setting, dark app icons, needs iOS 18.
                if #available(iOS 18.0, *) {
                    NavigationLink {
                        HomeScreenSettingsView()
                    } label: {
                        SettingsRow(title: "zc.settings.homeScreen".loc, systemImage: "apps.iphone", color: .blue)
                    }
                }

                NavigationLink {
                    WallpaperSettingsView()
                } label: {
                    SettingsRow(title: "zc.settings.wallpaper".loc, systemImage: "camera.macro", color: .cyan)
                }
            }

            Section {
                NavigationLink {
                    AppsSettingsView()
                } label: {
                    SettingsRow(title: "lc.tabView.apps".loc, systemImage: "square.grid.2x2.fill", color: .indigo)
                }
            }

            Section {
                NavigationLink {
                    AdvancedSettingsView()
                } label: {
                    SettingsRow(title: "zc.settings.advanced".loc, systemImage: "hammer.fill", color: .gray)
                }
            }
        }
        // Zeus may have brought a certificate, or the launch check found a
        // problem, since Settings last looked.
        .onAppear(perform: connection.reload)
    }
}
