//
//  ZeusCertificateFooter.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The note under the certificate on the Zeus page: where the certificate
/// came from and how it gets renewed, then, when Apple couldn't be asked
/// about it, why.
struct ZeusCertificateFooter: View {
    @Environment(ZeusConnection.self) private var connection

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.headerSpacing) {
            Text(note)

            if case .unavailable(let reason) = connection.validity {
                Text("zc.settings.zeus.couldNotCheckReason %@".localizeWithFormat(reason))
            }
        }
    }

    private var note: String {
        switch connection.source {
        case .zeus:
            "zc.settings.zeus.footerZeus".loc
        case .imported:
            "zc.settings.zeus.footerImported".loc
        case .none:
            "lc.settings.jitLessZeusDesc".loc
        }
    }
}
