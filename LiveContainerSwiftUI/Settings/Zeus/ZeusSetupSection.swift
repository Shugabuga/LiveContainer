//
//  ZeusSetupSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Check Setup on the Zeus page: the parts Zeus sets up when it signs
/// zContainer, how each stands, and the button that checks them all again,
/// signing a test library the way apps are signed and checking that iOS
/// accepts it.
struct ZeusSetupSection: View {
    @Environment(ZeusConnection.self) private var connection

    var body: some View {
        Section {
            ForEach(ZeusSetupCheck.allCases, id: \.self) { check in
                ZeusSetupRow(check: check, result: connection.result(for: check))
            }

            Button(action: checkSetup) {
                if connection.isCheckingSetup {
                    Label {
                        Text("zc.settings.setup.checking".loc)
                    } icon: {
                        ProgressView()
                    }
                } else {
                    Text("zc.settings.setup.check".loc)
                }
            }
            .disabled(connection.isCheckingSetup)
        } header: {
            Text("zc.settings.setup".loc)
        } footer: {
            Text("zc.settings.setup.footer".loc)
        }
    }

    private func checkSetup() {
        Task {
            await connection.checkSetup()
        }
    }
}
