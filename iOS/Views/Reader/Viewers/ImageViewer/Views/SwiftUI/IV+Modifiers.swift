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

