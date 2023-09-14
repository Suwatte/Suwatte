//
//  IV+Modifiers.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI

// MARK: Color Invert

struct ColorInvertModifier: ViewModifier {
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

// MARK: GrayScale

struct GrayScaleModifier: ViewModifier {
    @AppStorage(STTKeys.ReaderGrayScale) var useGrayscale = false

    func body(content: Content) -> some View {
        content
            .grayscale(useGrayscale ? 1 : 0)
    }
}

// MARK: Colored Overlay

struct CustomOverlayModifier: ViewModifier {
    @AppStorage(STTKeys.EnableOverlay) var overlayEnabled = false
    @AppStorage(STTKeys.OverlayColor) var overlayColor: Color = .clear
    @AppStorage(STTKeys.ReaderFilterBlendMode) var readerBlendMode = STTBlendMode.normal

    func body(content: Content) -> some View {
        content
            .overlay {
                if overlayEnabled {
                    overlayColor
                        .allowsHitTesting(false)
                        .blendMode(readerBlendMode.blendMode)
                }
            }
    }
}

// MARK: Background

struct CustomBackgroundModifier: ViewModifier {
    @AppStorage(STTKeys.BackgroundColor, store: .standard) var backgroundColor = Color.primary
    @AppStorage(STTKeys.UseSystemBG, store: .standard) var useSystemBG = true

    func body(content: Content) -> some View {
        content
            .background(useSystemBG ? nil : backgroundColor.ignoresSafeArea())
            .modifier(BackgroundTapModifier())
    }
}

// MARK: BackGround Tap

struct BackgroundTapModifier: ViewModifier {
    @EnvironmentObject var model: IVViewModel
    func body(content: Content) -> some View {
        content
            .background(Color.primary.opacity(0.01).gesture(tap))
    }

    var tap: some Gesture {
        TapGesture(count: 1)
            .onEnded { _ in
                Task { @MainActor in
                    model.toggleMenu()
                }
            }
    }
}

// MARK: AutoScroll

struct AutoScrollModifier: ViewModifier {
    @EnvironmentObject var model: IVViewModel
    @AppStorage(STTKeys.VerticalAutoScroll) var autoScrollEnabled = false

    var shouldShowOverlay: Bool {
        model.readingMode == .VERTICAL && autoScrollEnabled
    }

    func body(content: Content) -> some View {
        content
            .overlay(shouldShowOverlay ? AutoScrollOverlay() : nil)
    }
}

// MARK: Sheets

struct ReaderSheetsModifier: ViewModifier {
    @EnvironmentObject var model: IVViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $model.control.settings) {
                IVSettingsView()
            }
            .sheet(isPresented: $model.control.chapterList, onDismiss: reset) {
                IVChapterListView()
            }
    }

    private func reset() {
        guard let chapter = model.pendingState?.chapter else {
            return
        }
        Task {
            await model.resetToChapter(chapter)
        }
    }
}

// MARK: Menu

struct ReaderMenuModifier: ViewModifier {
    @EnvironmentObject var model: IVViewModel

    func body(content: Content) -> some View {
        content
            .overlay {
                if model.control.menu {
                    IVMenuView()
                }
            }
    }
}
