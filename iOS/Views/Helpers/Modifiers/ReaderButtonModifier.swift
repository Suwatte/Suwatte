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
            .frame(width: 25, height: 25, alignment: .center)
        
    }
}
