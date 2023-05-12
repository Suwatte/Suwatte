//
//  ColoredBadge.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-04-22.
//

import SwiftUI

struct ColoredBadge: View {
    var color: Color
    var bodySize: CGFloat = 15.0
    var internalSize: CGFloat = 10
    var offset: CGFloat = 6.5
    var body: some View {
        ZStack(alignment: .center) {
            Circle()
                .foregroundColor(.systemBackground)
            Circle()
                .foregroundColor(color)
                .frame(width: internalSize, height: internalSize)
        }
        .frame(width: bodySize, height: bodySize, alignment: .leading)
        .offset(x: offset, y: -offset)
        .transition(.scale)
    }
}
