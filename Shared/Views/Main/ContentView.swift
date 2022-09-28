//
//  ContentView.swift
//  Shared
//
//  Created by Mantton on 2022-02-28.
//

import AlertToast
import SwiftUI

struct ContentView: View {
    @State var tabs = AppTabs.defaultSettings
    @AppStorage(STTKeys.IntialTabIndex) var InitialSelection = 3
    @State var selection = 0
    @StateObject var toastModel = ToastManager.shared
    @StateObject var toaster = ToastManager2()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(zip(tabs.indices, tabs)), id: \.0) { index, tab in
                tab.view()
                    .tag(index)
                    .tabItem {
                        Image(systemName: "\(tab.systemImage())\(selection == index ? ".fill" : "")")
                            // SwiftUI AHIG Override: https://stackoverflow.com/a/70058260
                            .environment(\.symbolVariants, .none)
                    }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            selection = InitialSelection
            toaster.loading.toggle()
            toaster.display(.info("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."))
            toaster.display(.error(nil, "This is not right"))
            toaster.display(.info("2"))
            toaster.display(.info("3"))
            toaster.display(.info("4"))
            toaster.display(.info("5"))
            toaster.display(.info("6"))

        }
        .toast(isPresenting: $toastModel.show) { toastModel.toast }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                STTScheduler.shared.scheduleLibraryUpdate()
            default: break
            }
        }
        .toast2()
        .environmentObject(toaster)
    }
}
