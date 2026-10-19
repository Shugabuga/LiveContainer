//
//  DeveloperSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Advanced > Developer, which shows after tapping the version
/// under Advanced five times: LiveContainer's developer settings, the files
/// that can be copied out for debugging, and the symbol cache and FLEX.
struct DeveloperSettingsView: View {
    @AppStorage("LCLoadTweaksToSelf") private var injectToLCItself = false
    @AppStorage("LCIgnoreJITOnLaunch") private var ignoreJITOnLaunch = false
    @AppStorage("LCKeepSelectedWhenQuit") private var keepSelectedWhenQuit = false
    @AppStorage("LCWaitForDebugger") private var waitForDebugger = false
    @AppStorage("LCSharePrivateDataWithLiveProcess") private var sharePrivateDataWithLiveProcess = false
    @AppStorage("BKNoWatchdogs") private var disableLiveProcessWatchdog = false

    /// What an export wrote, while the message saying so shows.
    @State private var exportedFiles: [String]?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Toggle("lc.settings.injectLCItself".loc, isOn: $injectToLCItself)
            } footer: {
                Text("lc.settings.injectLCItselfDesc".loc)
            }

            Section {
                Toggle("zc.settings.developer.ignoreJIT".loc, isOn: $ignoreJITOnLaunch)
                Toggle("zc.settings.developer.keepSelected".loc, isOn: $keepSelectedWhenQuit)
                Toggle("zc.settings.developer.waitForDebugger".loc, isOn: $waitForDebugger)
                Toggle("zc.settings.developer.sharePrivateData".loc, isOn: $sharePrivateDataWithLiveProcess)
                Toggle("zc.settings.developer.noWatchdog".loc, isOn: $disableLiveProcessWatchdog)
            }

            Section {
                Button("zc.settings.developer.exportCertificate".loc, action: exportCertificate)
                Button("zc.settings.developer.exportDyld".loc, action: exportDyld)
                Button("zc.settings.developer.exportBundle".loc, action: exportMainBundle)
            } footer: {
                Text("zc.settings.developer.exportFooter".loc)
            }

            Section {
                Button("zc.settings.developer.resetSymbolOffsets".loc, action: DeveloperTools.resetSymbolOffsets)
                Button("zc.settings.developer.flex".loc, action: DeveloperTools.showFLEXOverlay)
                    .disabled(!DeveloperTools.isFLEXAvailable)
            }
        }
        .navigationTitle("zc.settings.developer".loc)
        .navigationBarTitleDisplayMode(.inline)
        .alert("lc.common.success".loc, item: $exportedFiles) { _ in
            Button("lc.common.ok".loc) { }
        } message: { files in
            Text(exportMessage(for: files))
        }
        .alert("lc.common.error".loc, item: $errorMessage) { _ in
            Button("lc.common.ok".loc) { }
        } message: { message in
            Text(message)
        }
    }

    private func exportCertificate() {
        export(with: DeveloperTools.exportCertificate)
    }

    private func exportDyld() {
        export(with: DeveloperTools.exportDyld)
    }

    private func exportMainBundle() {
        export(with: DeveloperTools.exportMainBundle)
    }

    /// Runs an export and says what it wrote, or what went wrong.
    private func export(with tool: () throws -> [String]) {
        do {
            exportedFiles = try tool()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportMessage(for files: [String]) -> String {
        if files.isEmpty {
            "zc.settings.developer.exportedNothing".loc
        } else {
            "zc.settings.developer.exported %@".localizeWithFormat(files.formatted())
        }
    }
}
