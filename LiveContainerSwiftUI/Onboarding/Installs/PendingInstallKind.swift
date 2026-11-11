//
//  PendingInstallKind.swift
//  LiveContainerSwiftUI
//

/// Where an app waiting in PendingInstallQueue came from, as the record
/// PendingInstallStore keeps of it says.
enum PendingInstallKind: String, Codable {
    /// An install link, whose IPA downloads into the app's folder.
    case link

    /// An IPA opened with zContainer or shared to it, which its bookmark
    /// finds again.
    case openedFile

    /// An IPA picked in Files, whose copy moved into the app's folder.
    case pickedFile

    /// An app Zeus left in the app group the two apps share, copied into the
    /// app's folder. Its request is read again from the group when the app
    /// comes back.
    case zeusRequest
}
