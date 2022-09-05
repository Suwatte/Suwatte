//
//  ReaderCustomOverlay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-09.
//

import SwiftUI

extension ReaderView {
    struct ReaderCustomOverlay: View {
        @AppStorage(STTKeys.OverlayColor) var overlayColor: Color = .clear
        @EnvironmentObject var model: ReaderView.ViewModel
        var body: some View {
            overlayColor
                .allowsHitTesting(false)
        }
    }
}
