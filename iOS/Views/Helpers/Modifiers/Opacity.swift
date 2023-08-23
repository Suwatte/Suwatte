//
//  Opacity.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-09.
//

import SwiftUI

struct OpacityViewModifier: ViewModifier {
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
