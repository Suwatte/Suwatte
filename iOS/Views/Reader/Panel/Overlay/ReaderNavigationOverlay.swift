//
//  ReaderNavigationOverlay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-20.
//

import SwiftUI

extension ReaderView {
    struct ReaderNavigationOverlay: View {
        @EnvironmentObject var model: ReaderView.ViewModel
        let szz = UIScreen.main.bounds.size
        var body: some View {
            ZStack {
                ForEach(STTHelpers.getNavigationMode().mode.regions) { region in
                    Canvas { context, _ in
                        context.fill(
                            Path(region.rect.rect(for: szz)),
                            with: .color(region.type.color)
                        )
                    }
                    .frame(width: szz.width, height: szz.height, alignment: .center)
                }
            }
            .allowsHitTesting(false)
            .opacity(0.35)
        }
    }
}
