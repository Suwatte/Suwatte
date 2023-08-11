//
//  IV+Modifiers.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI


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

struct GrayScaleModifier: ViewModifier {
    @AppStorage(STTKeys.ReaderGrayScale) var useGrayscale = false
    
    func body(content: Content) -> some View {
        content
            .grayscale(useGrayscale ? 1 : 0)
    }
}

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


struct CustomBackgroundModifier: ViewModifier {
    @AppStorage(STTKeys.BackgroundColor, store: .standard) var backgroundColor = Color.primary
    @AppStorage(STTKeys.UseSystemBG, store: .standard) var useSystemBG = true
    
    func body(content: Content) -> some View {
        content
            .background(useSystemBG ? nil : backgroundColor.ignoresSafeArea())
            .modifier(BackgroundTapModifier())
    }
}

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
