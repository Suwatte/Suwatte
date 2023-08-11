//
//  ImageViewer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI
import Nuke

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
        .overlay {
            if model.control.menu {
                IVMenuView()
            }
        }
        .statusBarHidden(!model.control.menu)
        .ignoresSafeArea()
        .animation(StandardAnimation, value: model.control)
        .animation(StandardAnimation, value: model.presentationState)
        .animation(StandardAnimation, value: model.viewerState)
        .animation(StandardAnimation, value: model.slider)
        .sheet(isPresented: $model.control.settings) {
            IVSettingsView()
                .onDisappear {
                    print("show overlay")
                }
        }
        .environmentObject(model)
        .onDisappear {
            Task { @MainActor in
                ImageCache.shared.removeAll()
            }
        }
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
            Text("Placeholder")
        default:
            BadPathView
        }
    }
    
    var BadPathView: some View {
        VStack (alignment: .center) {
            Text("ᕦ(▀̿ ̿ -▀̿ ̿ )つ/̵͇̿̿/’̿’̿ ̿ ̿̿ ̿̿ ̿̿")
                .font(.title3)
                .fontWeight(.bold)
            Text("how'd you get here?")
                .font(.subheadline)
        }
    }
}

extension ImageViewer {
    private func startup() async  {
        await model.consume(initial)
    }
    
    private var StandardAnimation: Animation {
        .easeInOut(duration: 0.3)
    }
}

struct InitialIVState {
    let chapters: [StoredChapter]
    let openTo: StoredChapter
    let pageIndex: Int?
    let pageOffset: CGFloat?
    let title: String
}
