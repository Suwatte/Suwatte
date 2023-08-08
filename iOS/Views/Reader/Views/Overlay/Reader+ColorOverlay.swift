//
//  Reader+ColorOverlay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI


struct ColorOverlay: View {
    @AppStorage(STTKeys.EnableOverlay) var overlayEnabled = false
    @AppStorage(STTKeys.OverlayColor) var overlayColor: Color = .clear
    @AppStorage(STTKeys.ReaderFilterBlendMode) var readerBlendMode = STTBlendMode.normal
    
    var body: some View {
        overlayColor
            .allowsHitTesting(false)
            .blendMode(readerBlendMode.blendMode)
            .opacity(overlayEnabled ? 1 : 0)
    }
}


enum STTBlendMode: Int, CaseIterable {
    case normal, screen, multiply
    
    var description: String {
        switch self {
        case .multiply:
            return "Multiply"
        case .normal:
            return "Normal"
        case .screen:
            return "Screen"
        }
    }
    
    var blendMode: BlendMode {
        switch self {
        case .normal:
            return .normal
        case .screen:
            return .screen
        case .multiply:
            return .multiply
        }
    }
}

