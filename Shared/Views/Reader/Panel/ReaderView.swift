//
//  ReaderView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-29.
//

import SwiftUI

struct ReaderView: View {
    @StateObject var model: ViewModel
    @AppStorage(STTKeys.EnableOverlay) var overlayEnabled = false
    @AppStorage(STTKeys.BackgroundColor) var backgroundColor = Color.primary
    @AppStorage(STTKeys.UseSystemBG) var useSystemBG = true
    @Preference(\.isReadingVertically) var isVertical
    @Preference(\.displayNavOverlay) var displayNavOverlay
    @Preference(\.tapSidesToNavigate) var tapSidesToNavigate
    @Preference(\.isDoublePagedEnabled) var isDoublePagedEnabled
    var body: some View {
        LoadableView(loadable: model.activeChapter.data, {
            ProgressView()
                .task {
                    let chapter = model.activeChapter.chapter
                    await model.loadChapter(chapter, asNextChapter: true)
                }
        }, {
            ProgressView()
        }, { error in
            ErrorView(error: error) {
                Task { @MainActor in
                    let chapter = model.activeChapter.chapter
                    await model.loadChapter(chapter, asNextChapter: true)
                }
            }
        }, { _ in
            GATEWAY
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .overlay(model.showNavOverlay && tapSidesToNavigate && displayNavOverlay ? ReaderNavigationOverlay() : nil)
        .overlay(overlayEnabled ? ReaderCustomOverlay() : nil)
        .overlay(model.menuControl.menu ? ReaderMenuOverlay() : nil)
        .statusBar(hidden: !model.menuControl.menu)
        .animation(.default, value: model.menuControl.menu)
        .animation(.default, value: model.showNavOverlay)
        .sheet(isPresented: $model.menuControl.settings, onDismiss: { model.showNavOverlay = true }) {
            NavigationView {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .closeButton()
            }
        }
//        .sheet(isPresented: $model.menuControl.chapterList) {
//            NavigationView {
//                ChapterSheet()
//                    .navigationTitle("Chapter List")
//                    .navigationBarTitleDisplayMode(.inline)
//                    .closeButton()
//            }
//        }
        .environmentObject(model)
        .onChange(of: model.slider.isScrubbing) { val in

            if val == false {
                model.scrubEndPublisher.send()
            }
        }
        .background(useSystemBG ? nil : backgroundColor.ignoresSafeArea())
        .background(Color.primary.opacity(0.01).gesture(model.bgTap))
        .ignoresSafeArea()
        .onAppear {
            model.showNavOverlay.toggle()
        }
        .onChange(of: model.showNavOverlay) { val in
            if !val
            { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                model.showNavOverlay = false
            }
        }
    }
}

extension ReaderView {
    var GATEWAY: some View {
        Group {
            if isVertical {
                VerticalViewer()
            } else {
                if !isDoublePagedEnabled {
                    PagedViewer()
                } else {
                    DoublePagedViewer()
                }
            }
        }
    }
}

extension ReaderView.ViewModel {
    var tap: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { [unowned self] in
                if !activeChapter.data.LOADED { menuControl.toggleMenu() }
                else { handleNavigation($0.location) }
            }
    }

    var bgTap: some Gesture {
        TapGesture(count: 1)
            .onEnded { _ in
                self.menuControl.toggleMenu()
            }
    }

    var ignore: some Gesture {
        TapGesture(count: 2)
            .onEnded { _ in self.menuControl.hideMenu() }
    }
}
