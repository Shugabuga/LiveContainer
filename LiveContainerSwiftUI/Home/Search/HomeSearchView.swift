//
//  HomeSearchView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Search over the blurred Home Screen, laid out like iOS 26's: results at
/// the top, and the search field at the bottom, above the keyboard. Before
/// anything is typed it suggests the apps opened most recently and offers the
/// hidden apps behind Face ID. With the keyboard down, the Home button under
/// the field closes search. VoiceOver stays in search while it is open.
struct HomeSearchView: View {
    @Environment(HomeScreenModel.self) private var model
    @FocusState private var isFieldFocused: Bool
    /// Whether the Home button shows under the field. It shows whenever the
    /// field doesn't have the keyboard. As search opens it waits a moment for
    /// the keyboard, so it doesn't flash, and shows if the keyboard never came.
    @State private var showsHomeButton = false

    var body: some View {
        @Bindable var model = model
        let metrics = model.metrics ?? .reference
        let query = model.searchQuery

        VStack(spacing: HomeDesign.searchSpacing) {
            ScrollView {
                VStack(spacing: HomeDesign.searchSpacing) {
                    HomeSearchResults(apps: model.searchResults, query: query, metrics: metrics)
                    if query.isEmpty {
                        HomeHiddenApps(metrics: metrics)
                    }
                }
                .padding(.horizontal, HomeDesign.searchMargin)
                .padding(.top, HomeDesign.searchSpacing)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            HomeSearchField(
                text: $model.searchText,
                isFocused: $isFieldFocused,
                onSubmit: model.openFirstSearchResult,
                onClose: model.closeSearch
            )
            .padding(.horizontal, HomeDesign.searchMargin)
            .padding(.bottom, HomeDesign.searchSpacing / 2)

            // The keyboard covers the bottom of the screen while it's up, so
            // the Home button shows under the field once it goes away.
            if showsHomeButton {
                HomeButton(action: model.goHome)
                    .padding(.bottom, HomeDesign.homeButtonBarPadding)
                    .transition(.opacity)
            }
        }
        .animation(HomeDesign.modeChange, value: showsHomeButton)
        .background {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear(perform: focusField)
        .task {
            await showHomeButtonIfUnfocused()
        }
        .onChange(of: isFieldFocused, fieldFocusChanged)
    }

    private func focusField() {
        isFieldFocused = true
    }

    /// Shows the Home button when the field still hasn't got the keyboard a
    /// moment after search opened, so it never stays missing.
    private func showHomeButtonIfUnfocused() async {
        try? await Task.sleep(for: HomeDesign.searchFocusWait)
        guard !Task.isCancelled else {
            return
        }
        showsHomeButton = !isFieldFocused
    }

    private func fieldFocusChanged(from wasFocused: Bool, to isFocused: Bool) {
        showsHomeButton = !isFocused
    }
}
