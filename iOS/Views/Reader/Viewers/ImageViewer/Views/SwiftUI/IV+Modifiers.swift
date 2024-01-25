//
//  IV+Modifiers.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI

// MARK: Color Invert

struct ColorInvertModifier: ViewModifier {
    @AppStorage(STTKeys.ReaderColorInvert) private var useColorInvert = false

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
    @AppStorage(STTKeys.ReaderGrayScale) private var useGrayscale = false

    func body(content: Content) -> some View {
        content
            .grayscale(useGrayscale ? 1 : 0)
    }
}

// MARK: Colored Overlay

struct CustomOverlayModifier: ViewModifier {
    @AppStorage(STTKeys.EnableOverlay) private var overlayEnabled = false
    @AppStorage(STTKeys.OverlayColor) private var overlayColor: Color = .clear
    @AppStorage(STTKeys.ReaderFilterBlendMode) private var readerBlendMode = STTBlendMode.normal

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
    @AppStorage(STTKeys.BackgroundColor, store: .standard) private var backgroundColor = Color.primary
    @AppStorage(STTKeys.UseSystemBG, store: .standard) private var useSystemBG = true

    func body(content: Content) -> some View {
        content
            .background(useSystemBG ? nil : backgroundColor.ignoresSafeArea())
            .modifier(BackgroundTapModifier())
    }
}

// MARK: BackGround Tap

struct BackgroundTapModifier: ViewModifier {
    @EnvironmentObject private var model: IVViewModel
    func body(content: Content) -> some View {
        content
            .background(Color.primary.opacity(0.01).gesture(tap))
    }

    private var tap: some Gesture {
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
    @EnvironmentObject private var model: IVViewModel
    @AppStorage(STTKeys.VerticalAutoScroll) private var autoScrollEnabled = false

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
    @EnvironmentObject private var model: IVViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $model.control.settings, onDismiss: { model.control.navigationRegions.toggle() }) {
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
    @EnvironmentObject private var model: IVViewModel

    func body(content: Content) -> some View {
        content
            .overlay {
                if model.control.menu {
                    IVMenuView()
                }
            }
    }
}

// MARK: Navigation Overlay

struct ReaderNavigationRegionModifier: ViewModifier {
    @EnvironmentObject private var model: IVViewModel
    @Preference(\.displayNavOverlay) private var displayNavOverlay
    @Preference(\.tapSidesToNavigate) var tapSidesToNavigate

    func body(content: Content) -> some View {
        content
            .overlay {
                if isOverlayEnabled {
                    NavigationRegionOverlay()
                        .transition(.opacity)
                }
            }
            .onAppear {
                model.control.navigationRegions.toggle()
            }
            .onChange(of: model.control.navigationRegions) { val in
                if !val { return }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    model.control.navigationRegions = false
                }
            }
            .animation(.default, value: model.control.navigationRegions)
    }

    var isOverlayEnabled: Bool {
        displayNavOverlay && tapSidesToNavigate && model.control.navigationRegions
    }
}

struct NavigationRegionOverlay: View {
    var body: some View {
        ZStack {
            ForEach(STTHelpers.getNavigationMode().mode.regions) { region in
                Canvas { context, _ in
                    context.fill(
                        Path(region.rect.rect(for: size)),
                        with: .color(region.type.color)
                    )
                }
                .frame(width: size.width, height: size.height, alignment: .center)
            }
        }
        .allowsHitTesting(false)
        .opacity(0.3)
    }

    private var size: CGSize {
        UIScreen.main.bounds.size
    }
}
