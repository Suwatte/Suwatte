//
//  Reader+NavigationGuide.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI


struct NavigationGuide: View {
    @Binding var presenting: Bool
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(STTHelpers.getNavigationMode().mode.regions) { region in
                    Canvas { context, _ in
                        context.fill(
                            Path(region.rect.rect(for: proxy.size)),
                            with: .color(region.type.color)
                        )
                    }
                    .frame(width: proxy.size.width,
                           height: proxy.size.height,
                           alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
        .opacity(presenting ? 0.35 : 0)
    }
}
