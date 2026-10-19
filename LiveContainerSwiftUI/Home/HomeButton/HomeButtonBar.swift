//
//  HomeButtonBar.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home button centered along the bottom of a screen opened over the Home
/// Screen. It steps aside while the keyboard is up, so it doesn't ride on top
/// of the keyboard while something is typed.
struct HomeButtonBar: View {
    /// What pressing the button does.
    let action: () -> Void

    @State private var isKeyboardShowing = false

    var body: some View {
        ZStack {
            if !isKeyboardShowing {
                HomeButton(action: action)
                    .padding(.vertical, HomeDesign.homeButtonBarPadding)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(HomeDesign.modeChange, value: isKeyboardShowing)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification), perform: keyboardWillShow)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification), perform: keyboardWillHide)
    }

    private func keyboardWillShow(_ notification: Notification) {
        isKeyboardShowing = true
    }

    private func keyboardWillHide(_ notification: Notification) {
        isKeyboardShowing = false
    }
}
