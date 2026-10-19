//
//  OnboardingSetupForm.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A step of onboarding laid out like iOS's own setup: a header on the page
/// itself, then grouped sections, so every step's header sits in the same
/// place.
struct OnboardingSetupForm<Header: View, Content: View>: View {
    @ContentBuilder let header: Header
    @ContentBuilder let content: Content

    var body: some View {
        Form {
            Section {
                header
            }
            .listRowBackground(Color.clear)

            content
        }
        // A page that fits stays put, like a page of iOS's own setup.
        .scrollBounceBehavior(.basedOnSize)
    }
}
