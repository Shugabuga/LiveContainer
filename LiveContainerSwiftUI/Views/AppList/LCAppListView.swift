//
//  ContentView.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/21.
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

class SearchContext: ObservableObject {
    @Published var query: String = ""
    @Published var debouncedQuery: String = ""
    @Published var isTyping: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        $query
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isTyping = true
                self?.debouncedQuery = value
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.isTyping = false
                }
            }
            .store(in: &cancellables)
    }
}

/// The app list: LiveContainer's banners, kept until the Home Screen replaces
/// them. Installing, launching and the questions those flows ask belong to the
/// AppLaunchCoordinator; this view keeps its own screens (Files, links, app
/// settings, sorting and help).
struct LCAppListView : View, LCAppBannerDelegate {
    // ipa choosing stuff
    @State var choosingIPA = false
    
    @StateObject private var webViewUrlInput = InputHelper()
    @StateObject private var installUrlInput = InputHelper()
    
    @StateObject private var generatedIconStyleSelector = AlertHelper<GeneratedIconStyle>()
    
    @State var safariViewOpened = false
    @State var safariViewURL = URL(string: "https://google.com")!
    
    @State private var navigateTo : AnyView?
    @State private var isNavigationActive = false
    
    @State private var helpPresent = false
    
    @State private var customSortViewPresent = false
    
    @EnvironmentObject private var sharedModel : SharedModel
    @EnvironmentObject private var sharedAppSortManager : LCAppSortManager
    @Environment(AppLaunchCoordinator.self) private var coordinator
    
    @AppStorage("LCMultitaskMode", store: LCUtils.appGroupUserDefault) var multitaskMode: MultitaskMode = .virtualWindow
    
    @ObservedObject var searchContext: SearchContext = SearchContext()
    var sortedApps: [LCAppModel] {
        return sharedAppSortManager.sortedApps
    }
    
    var sortedHiddenApps: [LCAppModel] {
        return sharedAppSortManager.sortedHiddenApps
    }
    
    var filteredApps: [LCAppModel] {
        let apps = sortedApps
        if searchContext.debouncedQuery.isEmpty {
            return apps
        } else {
            return apps.filter { app in
                app.appInfo.displayName().localizedCaseInsensitiveContains(searchContext.debouncedQuery) ||
                app.appInfo.bundleIdentifier()!.localizedCaseInsensitiveContains(searchContext.debouncedQuery)
            }
        }
    }
    
    var filteredHiddenApps: [LCAppModel] {
        let apps = sortedHiddenApps
        if searchContext.debouncedQuery.isEmpty || !sharedModel.isHiddenAppUnlocked {
            return apps
        } else {
            return apps.filter { app in
                app.appInfo.displayName().localizedCaseInsensitiveContains(searchContext.debouncedQuery) ||
                app.appInfo.bundleIdentifier()!.localizedCaseInsensitiveContains(searchContext.debouncedQuery)
            }
        }
    }
    
    init() {
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                NavigationLink(
                    destination: navigateTo,
                    isActive: $isNavigationActive,
                    label: {
                        EmptyView()
                })
                .hidden()
                
                LazyVStack {
                    ForEach(filteredApps, id: \.self) { app in
                        LCAppBanner(appModel: app, delegate: self)
                    }
                    .transition(.scale)
                }
                .padding()
                .animation(searchContext.isTyping ? nil : .easeInOut, value: filteredApps)

                VStack {
                    if LCUtils.appGroupUserDefault.bool(forKey: "LCStrictHiding") {
                        if sharedModel.isHiddenAppUnlocked {
                            LazyVStack {
                                HStack {
                                    Text("lc.appList.hiddenApps".loc)
                                        .font(.system(.title2).bold())
                                    Spacer()
                                }
                                
                                ForEach(filteredHiddenApps, id: \.self) { app in
                                    LCAppBanner(appModel: app, delegate: self)
                                }
                                .transition(.scale)
                                
                            }
                            .padding()
                            .transition(.opacity)
                            .animation(searchContext.isTyping ? nil : .easeInOut, value: filteredHiddenApps)
                            
                            if sharedModel.hiddenApps.count == 0 {
                                Text("lc.appList.hideAppTip".loc)
                                    .foregroundStyle(.gray)
                            }
                        }
                    } else if sharedModel.hiddenApps.count > 0 {
                        LazyVStack {
                            HStack {
                                Text("lc.appList.hiddenApps".loc)
                                    .font(.system(.title2).bold())
                                Spacer()
                            }
                            ForEach(filteredHiddenApps, id: \.self) { app in
                                if sharedModel.isHiddenAppUnlocked {
                                    LCAppBanner(appModel: app, delegate: self)
                                } else {
                                    LCAppSkeletonBanner()
                                }
                            }
                            .animation(.easeInOut, value: sharedModel.isHiddenAppUnlocked)
                            .onTapGesture {
                                Task { await authenticateUser() }
                            }
                        }
                        .padding()
                        .animation(searchContext.isTyping ? nil : .easeInOut, value: filteredHiddenApps)
                    }

                    let appCount = sharedModel.isHiddenAppUnlocked ? filteredApps.count + filteredHiddenApps.count : filteredApps.count
                    Text(appCount > 0 || searchContext.debouncedQuery != "" ? "lc.appList.appCounter %lld".localizeWithFormat(appCount) : (sharedModel.multiLCStatus == 2 ? "lc.appList.convertToSharedToShowInLC2".loc : "lc.appList.installTip".loc))
                        .padding(.horizontal)
                        .foregroundStyle(.gray)
                        .animation(searchContext.isTyping ? nil : .easeInOut, value: appCount)
                        .onTapGesture(count: 3) {
                            Task { await authenticateUser() }
                        }
                }.animation(searchContext.isTyping ? nil : .easeInOut, value: LCUtils.appGroupUserDefault.bool(forKey: "LCStrictHiding"))

                if sharedModel.multiLCStatus == 2 {
                    Text("lc.appList.manageInPrimaryTip".loc).foregroundStyle(.gray).padding()
                }

            }
            .navigationBarProgressBar(show: Bindable(coordinator).isInstalling, progress: Bindable(coordinator).installProgress)
            .coordinateSpace(name: "scroll")

            .navigationTitle("lc.appList.myApps".loc)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if sharedModel.multiLCStatus != 2 {
                        if !coordinator.isInstalling {
                            Menu {
                                
                                Button("lc.appList.installFromIpa".loc, systemImage: "doc.badge.plus", action: {
                                    choosingIPA = true
                                })
                                Button("lc.appList.installFromUrl".loc, systemImage: "link.badge.plus", action: {
                                    Task{ await startInstallFromUrl() }
                                })
                            } label: {
                                Label("add", systemImage: "plus")
                            }
                            
                        } else {
                            ProgressView().progressViewStyle(.circular).padding(.horizontal, 8)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Help", systemImage: "questionmark") {
                        helpPresent = true
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("lc.appList.openLink".loc, systemImage: "link", action: {
                        Task { await onOpenWebViewTapped() }
                    })
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $sharedAppSortManager.appSortType) {
                            ForEach(AppSortType.allCases, id: \.self) { sortType in
                                Label(sortType.displayName, systemImage: sortType.systemImage)
                                    .tag(sortType)
                            }
                        }
                        .onChange(of: sharedAppSortManager.appSortType) { newValue in
                            if sharedAppSortManager.appSortType == .custom {
                                customSortViewPresent = true
                            }
                        }
                        if sharedAppSortManager.appSortType == .custom {
                            Divider()
                            
                            Button {
                                customSortViewPresent = true
                            } label: {
                                Label("lc.appList.sort.customManage".loc, systemImage: "slider.horizontal.3")
                            }
                        }
                    } label: {
                        Label("Sort by", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .betterFileImporter(isPresented: $choosingIPA, types: [.ipa, .tipa], multiple: false, callback: { fileUrls in
            Task { await coordinator.startInstallApp(fileUrls[0]) }
        }, onDismiss: {
            choosingIPA = false
        })
        .alert("lc.appList.generatedIconStyleSelector.title".loc, isPresented:$generatedIconStyleSelector.show) {
            Button {
                generatedIconStyleSelector.close(result: .Light)
            } label: {
                Text("lc.appList.generatedIconStyleSelector.light".loc)
            }
            Button {
                generatedIconStyleSelector.close(result: .Dark)
            } label: {
                Text("lc.appList.generatedIconStyleSelector.dark".loc)
            }
            Button {
                generatedIconStyleSelector.close(result: .Original)
            } label: {
                Text("lc.appList.generatedIconStyleSelector.original".loc)
            }
            Button("lc.common.cancel".loc, role: .cancel) {
                generatedIconStyleSelector.close(result: nil)
            }
        }
        .textFieldAlert(
            isPresented: $webViewUrlInput.show,
            title:  "lc.appList.enterUrlTip".loc,
            text: $webViewUrlInput.initVal,
            placeholder: "scheme://",
            action: { newText in
                webViewUrlInput.close(result: newText)
            },
            actionCancel: {_ in
                webViewUrlInput.close(result: nil)
            }
        )
        .textFieldAlert(
            isPresented: $installUrlInput.show,
            title:  "lc.appList.installUrlInputTip".loc,
            text: $installUrlInput.initVal,
            placeholder: "https://",
            action: { newText in
                installUrlInput.close(result: newText)
            },
            actionCancel: {_ in
                installUrlInput.close(result: nil)
            }
        )
        .fullScreenCover(isPresented: $safariViewOpened) {
            SafariView(url: $safariViewURL)
        }
        .sheet(isPresented: $helpPresent) {
            LCHelpView(isPresent: $helpPresent)
        }
        .sheet(isPresented: $customSortViewPresent) {
            LCCustomSortView()
        }
        .onChange(of: coordinator.appSettingsCloseRequests) {
            closeNavigationView()
        }
        .onDrop(of: [.url], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url else { return }
                Task {
                    guard let urlToOpen = await webViewUrlInput.open(initVal: url.absoluteString), urlToOpen != "" else {
                        return
                    }
                    await coordinator.openWebView(urlString: urlToOpen)
                }
            }
            return true
        }
        .searchable(text: $searchContext.query)

    }
    
    func onOpenWebViewTapped() async {
        guard let urlToOpen = await webViewUrlInput.open(), urlToOpen != "" else {
            return
        }
        await coordinator.openWebView(urlString: urlToOpen)
    }
    
    func startInstallFromUrl() async {
        guard let installUrlStr = await installUrlInput.open(), installUrlStr.count > 0 else {
            return
        }
        if let url = URL(string:installUrlStr), url.scheme?.lowercased() == "itms-services" {
            await coordinator.installFromPlist(urlStr: installUrlStr)
            return
        }
        await coordinator.installFromUrl(urlStr: installUrlStr)
    }
    
    func removeApp(app: LCAppModel) {
        coordinator.removeApp(app: app)
    }
    
    func authenticateUser() async {
        do {
            if !(try await LCUtils.authenticateUser()) {
                return
            }
        } catch {
            coordinator.errorMessage = error.localizedDescription
            return
        }
    }
    
    func installMdm(data: Data) {
        safariViewURL = URL(string:"data:application/x-apple-aspen-config;base64,\(data.base64EncodedString())")!
        safariViewOpened = true
    }
    
    func openNavigationView(view: AnyView) {
        navigateTo = view
        isNavigationActive = true
    }
    
    func promptForGeneratedIconStyle() async -> GeneratedIconStyle? {
        if #available(iOS 18.0, *) {
            return await generatedIconStyleSelector.open()
        } else {
            return .Light
        }
        
    }
    
    func closeNavigationView() {
        isNavigationActive = false
        navigateTo = nil
    }
}

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}