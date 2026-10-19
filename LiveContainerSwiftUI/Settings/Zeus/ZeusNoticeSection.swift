//
//  ZeusNoticeSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What is wrong, at the top of the Zeus page when zContainer can't sign
/// apps, with a button that opens Zeus, since signing zContainer again in
/// Zeus fixes most of it.
struct ZeusNoticeSection: View {
    /// What is wrong.
    let attention: ZeusAttention

    @Environment(ZeusConnection.self) private var connection

    var body: some View {
        Section {
            Label {
                Text(message)
            } icon: {
                Image(systemName: attention == .notSetUp ? "info.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(attention == .notSetUp ? Color.secondary : Color.red)
            }

            ZeusOpenButton()
        }
    }

    /// The problem LCZeusCertificate or the launch check recorded, when there
    /// is one, or what the attention means.
    private var message: String {
        if let problem = connection.problem {
            return problem
        }
        return switch attention {
        case .notSetUp:
            "lc.settings.jitLessZeusDesc".loc
        case .problem:
            "zc.settings.zeus.signingFailedNotice".loc
        case .expired:
            "zc.settings.zeus.expiredNotice".loc
        case .revoked:
            "zc.settings.zeus.revokedNotice".loc
        }
    }
}
