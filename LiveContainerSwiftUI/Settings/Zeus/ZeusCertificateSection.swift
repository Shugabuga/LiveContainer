//
//  ZeusCertificateSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The certificate zContainer signs apps with, on the Zeus page: where it came
/// from, its team, when it expires, what Apple says about it and when it was
/// stored.
struct ZeusCertificateSection: View {
    @Environment(ZeusConnection.self) private var connection

    var body: some View {
        Section {
            LabeledContent("zc.settings.zeus.source".loc, value: connection.source.title)

            if let teamID = connection.teamID {
                LabeledContent("lc.jitlessDiag.teamId".loc, value: teamID)
            }

            if let expiresAt = connection.expiresAt {
                LabeledContent("zc.settings.zeus.expires".loc) {
                    Text(expiresAt, format: .dateTime.day().month().year())
                        .foregroundStyle(connection.isExpired ? Color.red : Color.secondary)
                }
            }

            LabeledContent("zc.settings.zeus.status".loc) {
                ZeusValidityLabel(validity: connection.validity)
            }

            if let updatedAt = connection.updatedAt {
                LabeledContent("zc.settings.zeus.updated".loc) {
                    Text(updatedAt, format: .dateTime.day().month().year().hour().minute())
                }
            }
        } header: {
            Text("zc.settings.zeus.certificate".loc)
        } footer: {
            ZeusCertificateFooter()
        }
    }
}
