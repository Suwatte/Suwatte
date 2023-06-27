//
//  ReaderView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-29.
//

import SwiftUI

struct ReaderView: View {
    @StateObject var model: ViewModel
    @AppStorage(STTKeys.EnableOverlay, store: .standard) var overlayEnabled = false
    @AppStorage(STTKeys.BackgroundColor, store: .standard) var backgroundColor = Color.primary
    @AppStorage(STTKeys.UseSystemBG, store: .standard) var useSystemBG = true
    @AppStorage(STTKeys.VerticalAutoScroll, store: .standard) var verticalAutoScroll = false

    @AppStorage(STTKeys.ReaderType) var readerType = PanelReadingModes.PAGED_COMIC

    @Preference(\.isReadingVertically) var isVertical
    @Preference(\.displayNavOverlay) var displayNavOverlay
    @Preference(\.tapSidesToNavigate) var tapSidesToNavigate
    @Preference(\.isDoublePagedEnabled) var isDoublePagedEnabled
    @Preference(\.isPagingVertically) var isPagingVertically
    var body: some View {
        LoadableView(loadable: model.activeChapter.data, {
            VStack(alignment: .center) {
                ProgressView()
                Text("Fetching Images...")
                    .font(.footnote)
                    .fontWeight(.light)
            }
            .task {
                let chapter = model.activeChapter.chapter
                await model.loadChapter(chapter, asNextChapter: true)
            }
            .transition(.opacity)
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
        .modifier(UseGrayScaleModifier())
        .modifier(UseColorInvertModifier())
        .overlay(model.menuControl.menu ? ReaderMenuOverlay() : nil)
        .overlay(isVertical && verticalAutoScroll ? AutoScrollOverlay() : nil)
        .statusBar(hidden: !model.menuControl.menu)
        .animation(.default, value: model.menuControl.menu)
        .animation(.default, value: model.showNavOverlay)
        .sheet(isPresented: $model.menuControl.settings, onDismiss: { model.showNavOverlay = true }) {
            NavigationView {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .closeButton()
                    .defaultAppStorage(.standard)
            }
        }
        .sheet(isPresented: $model.menuControl.chapterList) {
            NavigationView {
                ChapterSheet()
                    .navigationTitle("Chapter List")
                    .navigationBarTitleDisplayMode(.inline)
                    .closeButton()
            }
        }
        .animation(.default, value: isVertical)
        .animation(.default, value: isDoublePagedEnabled)
        .animation(.default, value: model.activeChapter.data)
        .environmentObject(model)
        .onChange(of: model.slider.isScrubbing) { val in

            if val == false {
                model.scrubEndPublisher.send()
            }
        }
        .onChange(of: model.menuControl.menu, perform: { newValue in
            if !newValue {
                model.slider.isScrubbing = false
            }
        })
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
        .toast()
    }
}

extension ReaderView {
    var GATEWAY: some View {
        Group {
            if !model.containerReady {
                VStack(alignment: .center) {
                    ProgressView()
                    Text("Preparing Reader...")
                        .font(.footnote)
                        .fontWeight(.light)
                        .opacity(0.5)
                }
                .transition(.opacity)
            } else {
                if isVertical {
                    VerticalViewer()
                        .transition(.opacity)
                } else {
                    if isPagingVertically {
                        VerticalPager()
                            .transition(.opacity)
                    } else {
                        if !isDoublePagedEnabled {
                            PagedViewer()
                                .transition(.opacity)
                        } else {
                            DoublePagedViewer()
                                .transition(.opacity)
                        }
                    }
                }
            }
        }
    }
}

extension ReaderView.ViewModel {
    var bgTap: some Gesture {
        TapGesture(count: 1)
            .onEnded { _ in
                self.menuControl.toggleMenu()
            }
    }
}

extension ReaderView {
    struct UseColorInvertModifier: ViewModifier {
        @AppStorage(STTKeys.ReaderColorInvert) var useColorInvert = false

        func body(content: Content) -> some View {
            if useColorInvert {
                content
                    .colorInvert()
            } else {
                content
            }
        }
    }

    struct UseGrayScaleModifier: ViewModifier {
        @AppStorage(STTKeys.ReaderGrayScale) var useGrayscale = false

        func body(content: Content) -> some View {
            content
                .grayscale(useGrayscale ? 1 : 0)
        }
    }
}
