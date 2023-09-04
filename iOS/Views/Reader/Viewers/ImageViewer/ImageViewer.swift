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
        LoadableView(startup, $model.presentationState) { _ in
            MainView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
            guard UIDevice.current.userInterfaceIdiom == .pad, orientation.isLandscape && !doublePaged else {
                return
            }
            model.producePendingState()
            doublePaged = true
        })
        .toast()
    }
}

extension ImageViewer {
    @ViewBuilder
    var MainView: some View {
        switch model.readingMode {
        case .PAGED_COMIC, .PAGED_MANGA:
            if doublePaged {
                DoublePagedImageViewer()
            } else {
                PagedImageViewer()
            }
        case .PAGED_VERTICAL:
            VerticalPagedViewer()
        case .VERTICAL:
            WebtoonViewer()
        default:
            ProgressView()
        }
    }
}

extension ImageViewer {
    private func startup() async {
        await model.consume(initial)
    }

    private var StandardAnimation: Animation {
        .easeInOut(duration: 0.3)
    }
}

