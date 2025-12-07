//
//  ContentView.swift
//  Shared
//
//  Created by Mantton on 2022-02-28.
//

import SwiftUI

struct ContentView: View {
    var tabs = AppTabs.defaultSettings
    @AppStorage(STTKeys.IntialTabIndex) var InitialSelection = 3
    @State var selection = 0
    @StateObject var toaster = ToastManager.shared
    @StateObject var appState = StateManager.shared
    @EnvironmentObject var navModel: NavigationModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        MainContent
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .background:
                    STTScheduler.shared.scheduleAll()
                default: break
                }
                appState.didScenePhaseChange(phase)
            }
            .onAppear {
                selection = InitialSelection
            }
            .fullScreenCover(item: $navModel.content) { taggedHighlight in
                SmartNavigationView {
                    ProfileView(entry: taggedHighlight.highlight, sourceId: taggedHighlight.sourceID)
                        .closeButton()
                        .environmentObject(ToastManager.shared)
                }
            }
            .fullScreenCover(item: $navModel.link) { taggedLink in
                SmartNavigationView {
                    PageLinkView(link: taggedLink.link.link, title: taggedLink.link.title, runnerID: taggedLink.sourceID)
                        .closeButton()
                }
            }
            .fullScreenCover(item: $appState.readerState) { ctx in
                ReaderGateWay(title: ctx.title,
                              readingMode: ctx.readingMode ?? .defaultPanelMode,
                              chapterList: ctx.chapters,
                              openTo: ctx.chapter,
                              pageIndex: ctx.requestedPage.flatMap { $0 - 1 },
                              pageOffset: ctx.requestedOffset)
                    .onDisappear(perform: ctx.dismissAction)
            }
            .task {
                await startup()
            }
            .environmentObject(toaster)
            .environmentObject(appState)
    }

    var MainContent: some View {
        TabView(selection: $selection) {
            ForEach(tabs, id: \.rawValue) { tab in
                tab.view()
                    .tag(tab.rawValue)
                    .tabItem {
                        Image(systemName: "\(tab.systemImage())\(selection == tab.rawValue ? ".fill" : "")")
                            // SwiftUI AHIG Override: https://stackoverflow.com/a/70058260
                            .environment(\.symbolVariants, .none)
                    }
                    .toast()
            }
        }
    }

    private func startup() async {
        appState.initialize()
        await appState.observe()

        // Notification Center

        do {
            let center = UNUserNotificationCenter.current()
            try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            Logger.shared.error(error)
        }

        Task { @MainActor in
            if !UserDefaults.standard.bool(forKey: STTKeys.OldProgressMarkersMigrated) {
                await MigrationHelper.migrateProgressMarker()
            }
        }
    }
}

struct STTContentBlur: ViewModifier {
    @AppStorage(STTKeys.BlurWhenAppSwiching) var blurDuringSwitch = false
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        ZStack {
            if ShouldBlur {
                Image("stt_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.all)
            } else {
                content
            }
        }
        .transition(.opacity)
        .animation(.default, value: scenePhase)
        .animation(.default, value: ShouldBlur)
    }

    var ShouldBlur: Bool {
        blurDuringSwitch && scenePhase != .active
    }

    var ContentBlur: Double {
        ShouldBlur ? 10 : 0
    }
}

extension View {
    func sttContentBlur() -> some View {
        modifier(STTContentBlur())
    }
}
