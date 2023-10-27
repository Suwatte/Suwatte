//
//  ImageViewer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Nuke
import SwiftUI

struct ImageViewer: View {
    var initial: InitialIVState

    @Preference(\.isDoublePagedEnabled)
    var doublePaged

    @StateObject
    private var model = IVViewModel()

    var body: some View {
        OldLoadableView(startup, $model.presentationState) { _ in
            MainView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .modifier(ReaderNavigationRegionModifier())
        .modifier(CustomOverlayModifier())
        .modifier(GrayScaleModifier())
        .modifier(ColorInvertModifier())
        .modifier(ReaderMenuModifier())
        .modifier(AutoScrollModifier())
        .statusBarHidden(!model.control.menu)
        .modifier(CustomBackgroundModifier())
        .ignoresSafeArea()
        .animation(StandardAnimation, value: model.control)
        .animation(StandardAnimation, value: model.presentationState)
        .animation(StandardAnimation, value: model.viewerState)
        .animation(StandardAnimation, value: model.slider)
        .modifier(ReaderSheetsModifier())
        .environmentObject(model)
        .onDisappear {
            Task { @MainActor in
                ImageCache.shared.removeAll()
            }
        }
        .onRotate(perform: { orientation in
            guard UIDevice.current.userInterfaceIdiom == .pad, orientation.isLandscape, !doublePaged else {
                return
            }
            model.producePendingState()
            doublePaged = true
        })
        .toast()
    }
}

extension ImageViewer {
    var MainView: some View {
        ZStack {
            switch model.readingMode {
            case .PAGED_COMIC, .PAGED_MANGA:
                if doublePaged {
                    DoublePagedImageViewer()
                        .transition(.opacity)
                } else {
                    PagedImageViewer()
                        .transition(.opacity)
                }
            case .PAGED_VERTICAL:
                VerticalPagedViewer()
                    .transition(.opacity)
            case .VERTICAL:
                WebtoonViewer()
                    .transition(.opacity)
            default:
                ProgressView()
                    .transition(.opacity)
            }
        }
        .animation(StandardAnimation, value: model.readingMode)
        .animation(StandardAnimation, value: doublePaged)
    }
}

extension ImageViewer {
    private func startup() async throws {
        try await model.consume(initial)
    }

    private var StandardAnimation: Animation {
        .easeInOut(duration: 0.3)
    }
}
