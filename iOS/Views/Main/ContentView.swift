//
//  ContentView.swift
//  Shared
//
//  Created by Mantton on 2022-02-28.
//

import SwiftUI

struct ContentView: View {
    @State var tabs = AppTab.tabs
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
                appState.initialize()
                await appState.observe()
            }
            .environmentObject(toaster)
            .environmentObject(appState)
    }

    var tabSelection: Binding<Int> {
        Binding {
            self.selection
        } set: { tappedTab in

            if tappedTab == self.selection {
                if let index = tabs.firstIndex(where: { $0.tab.rawValue == tappedTab }) {
                    tabs[index] = .init(tab: tabs[index].tab)
                }
            }

            self.selection = tappedTab
        }
    }

    var MainContent: some View {
        TabView(selection: self.tabSelection) {
            ForEach(tabs, id: \.id) { tab in
                tab
                    .tag(tab.tab.rawValue)
                    .tabItem {
                        Image(systemName: "\(tab.tab.systemImage())\(selection == tab.tab.rawValue ? ".fill" : "")")
                            // SwiftUI AHIG Override: https://stackoverflow.com/a/70058260
                            .environment(\.symbolVariants, .none)
                    }
                    .toast()

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
