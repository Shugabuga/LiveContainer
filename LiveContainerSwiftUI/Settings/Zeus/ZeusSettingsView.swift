//
//  ZeusSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Zeus, the page behind the card at the top of Settings, laid out
/// like the Apple Account page: Zeus's icon and what Zeus does for zContainer,
/// what is wrong when something is, the certificate Zeus gave zContainer,
/// Check Setup, and, last, importing a certificate by hand.
///
/// It asks Apple about the certificate when it opens, and again whenever a
/// different certificate is stored.
struct ZeusSettingsView: View {
    @Environment(ZeusConnection.self) private var connection

    var body: some View {
        List {
            Section {
                ZeusHeader()
            }
            .listRowBackground(Color.clear)

            if let attention = connection.attention {
                ZeusNoticeSection(attention: attention)
            }

            if connection.hasCertificate {
                ZeusCertificateSection()
            }

            ZeusSetupSection()

            if connection.isSecondary {
                Section {
                    Text("lc.settings.multiLCIsSecond".loc)
                        .foregroundStyle(.secondary)
                }
            } else {
                ZeusCertificateActions()
            }
        }
        .navigationTitle("zc.settings.zeus".loc)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: connection.certificateVersion)
        .onAppear(perform: connection.reload)
        .task(id: connection.certificateVersion) {
            await connection.checkCertificateIfNeeded()
        }
    }
}
