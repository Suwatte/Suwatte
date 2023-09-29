//
//  ReaderButtonModifier.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-31.
//

import SwiftUI

// MARK: Reader Button Modifier

struct ReaderButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 27.5, height: 27.5, alignment: .center)
    }
}
