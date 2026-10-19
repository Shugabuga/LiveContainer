//
//  ZeusCertificateActions.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The other ways to get a certificate, last on the Zeus page: importing one
/// by hand, removing the one stored, and putting back the one Zeus put inside
/// zContainer. While zContainer holds Zeus's certificate file, removing
/// Zeus's certificate would only bring it back on the next launch, so the
/// page offers a certificate of the person's own instead.
struct ZeusCertificateActions: View {
    @Environment(ZeusConnection.self) private var connection

    var body: some View {
        Section {
            if !connection.hasCertificate {
                ZeusImportCertificateButton(title: "lc.settings.importCertificate".loc)
            } else if connection.source == .zeus && connection.isBundled {
                ZeusImportCertificateButton(title: "lc.settings.importOtherCertificate".loc)
            } else {
                ZeusRemoveCertificateButton()
            }

            if connection.source != .zeus && connection.isBundled {
                ZeusRestoreCertificateButton()
            }
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        switch connection.source {
        case .none:
            "zc.settings.zeus.actionsFooterNone".loc
        case .zeus:
            connection.isBundled ? "zc.settings.zeus.actionsFooterBundled".loc : "zc.settings.zeus.actionsFooterZeus".loc
        case .imported:
            "zc.settings.zeus.actionsFooterImported".loc
        }
    }
}
