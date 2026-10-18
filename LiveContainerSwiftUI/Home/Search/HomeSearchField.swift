//
//  HomeSearchField.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The search field at the bottom of search, in a glass capsule, with a
/// button beside it that closes search.
struct HomeSearchField: View {
    /// What is typed.
    @Binding var text: String
    /// Whether the field has the keyboard.
    var isFocused: FocusState<Bool>.Binding
    /// Opens the best match, as the keyboard's Go key does.
    let onSubmit: () -> Void
    /// Closes search.
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("zc.home.search".loc, text: $text)
                    .focused(isFocused)
                    .submitLabel(.go)
                    .onSubmit(onSubmit)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !text.isEmpty {
                    Button(action: clear) {
                        Label("zc.home.clearSearch".loc, systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: HomeDesign.minimumTouchSize, minHeight: HomeDesign.minimumTouchSize)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, HomeDesign.searchPanelPadding)
            .padding(.trailing, text.isEmpty ? HomeDesign.searchPanelPadding : 4)
            .frame(minHeight: HomeDesign.searchFieldHeight)
            .homeGlass(.capsule)

            Button(action: onClose) {
                Label("lc.common.close".loc, systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: HomeDesign.searchFieldHeight, height: HomeDesign.searchFieldHeight)
                    .homeGlass(.circle, isInteractive: true)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
        }
    }

    private func clear() {
        text = ""
    }
}
