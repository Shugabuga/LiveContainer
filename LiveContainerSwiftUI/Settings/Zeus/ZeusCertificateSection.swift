//
//  ZeusCertificateSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The certificate zContainer signs apps with, on the Zeus page: what Apple
/// says about it, its team and when it expires. The note under it says where
/// it came from.
struct ZeusCertificateSection: View {
    @Environment(ZeusConnection.self) private var connection

    var body: some View {
        Section {
            LabeledContent("zc.settings.zeus.status".loc) {
                ZeusValidityLabel(validity: connection.validity)
            }

            if let teamID = connection.teamID {
                LabeledContent("lc.jitlessDiag.teamId".loc, value: teamID)
            }

            if let expiresAt = connection.expiresAt {
                LabeledContent("zc.settings.zeus.expires".loc) {
                    Text(expiresAt, format: .dateTime.day().month().year())
                        .foregroundStyle(connection.isExpired ? Color.red : Color.secondary)
                }
            }
        } header: {
            Text("zc.settings.zeus.certificate".loc)
        } footer: {
            ZeusCertificateFooter()
        }
    }
}
