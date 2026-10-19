//
//  AppIconFile.swift
//  LiveContainerSwiftUI
//

import CoreTransferable
import UniformTypeIdentifiers

/// An app's icon as a PNG file, which Save App Icon hands to Files.
struct AppIconFile: Transferable {
    /// The icon's PNG data.
    let png: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { file in
            file.png
        }
    }
}
