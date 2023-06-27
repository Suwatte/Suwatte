//
//  ViewHeightReader.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import SwiftUI

struct ViewSizeReader: ViewModifier {
    @Binding var size: CGSize

    func body(content: Content) -> some View {
        content
            .background(Reader($size))
    }

    fileprivate func Reader(_ binding: Binding<CGSize>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)

            DispatchQueue.main.async {
                binding.wrappedValue = rect.size
            }
            return .clear
        }
    }
}
