//
//  ReaderCustomOverlay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-09.
//

import SwiftUI

extension ReaderView {
    struct ReaderCustomOverlay: View {
        @AppStorage(STTKeys.OverlayColor, store: .standard) var overlayColor: Color = .clear
        @AppStorage(STTKeys.ReaderFilterBlendMode, store: .standard) var readerBlendMode = ReaderBlendMode.normal

        @EnvironmentObject var model: ReaderView.ViewModel
        var body: some View {
            overlayColor
                .allowsHitTesting(false)
                .blendMode(readerBlendMode.blendMode)
        }
    }
}
