//
//  ImageViewer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI


struct ImageViewer: View {
    var initial: InitialIVState
    
    @StateObject
    private var model = IVViewModel()
    
    var body: some View {
        LoadableView(startup, $model.presentationState) { _ in
            PagedImageViewer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .overlay {
            if model.control.menu {
                IVMenuView()
            }
        }
        .modifier(GrayScaleModifier())
        .modifier(ColorInvertModifier())
        .statusBarHidden(!model.control.menu)
        .ignoresSafeArea()
        .animation(StandardAnimation, value: model.control)
        .animation(StandardAnimation, value: model.presentationState)
        .animation(StandardAnimation, value: model.viewerState)
        .environmentObject(model)
    }
    
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


struct OpacityViewModifier : ViewModifier {
    var show: Bool = true
    func body(content: Content) -> some View {
        content
            .opacity(show ? 1 : 0)
    }
}
extension View {
    func showIf(_ bool: Bool) -> some View {
        modifier(OpacityViewModifier(show: bool))
    }
}
