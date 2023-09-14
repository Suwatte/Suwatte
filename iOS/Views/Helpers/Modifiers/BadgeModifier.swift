//
//  BadgeModifier.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import SwiftUI

struct BadgeModifer: ViewModifier {
    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
                .padding()
                .background(Color.blue)
            Text("100")
                .padding(.all, 2)
                .clipShape(Capsule())
//                .border(.red)
                .alignmentGuide(.top) { $0[.bottom] }
                .alignmentGuide(.trailing) { $0[.trailing] - $0.width * 0.25 }
                .background(Color.red)
        }
    }
}
