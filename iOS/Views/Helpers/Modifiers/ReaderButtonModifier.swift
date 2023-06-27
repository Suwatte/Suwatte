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
            .scaledToFit()
            .frame(width: 23, height: 23, alignment: .center)
            .padding(.all, 5)
    }
}
