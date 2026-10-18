//
//  HomeSearchView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Search over the blurred Home Screen, laid out like iOS 26's: results at
/// the top, and the search field at the bottom, above the keyboard. Before
/// anything is typed it suggests the apps opened most recently and offers the
/// hidden apps behind Face ID.
struct HomeSearchView: View {
    @Environment(HomeScreenModel.self) private var model
    @FocusState private var isFieldFocused: Bool

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
        }
        .background {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
        }
        .onAppear(perform: focusField)
    }

    private func focusField() {
        isFieldFocused = true
    }
}
