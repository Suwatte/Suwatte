//
//  IV+AutoScroll.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-21.
//

import SwiftUI
import UIKit

struct AutoScrollOverlay: View {
    @State var isScrolling = false
    private let publisher = PanelPublisher.shared

    @MainActor
    private var edges : UIEdgeInsets? {
        let window = getKeyWindow()
        return window?.safeAreaInsets
    }
    
    var body: some View {
        ZStack {
            Button {
                action()
            } label: {
                Image(systemName: isScrolling ? "pause.circle" : "play.circle")
                    .resizable()
                    .scaledToFit()
                    .modifier(ReaderButtonModifier())
                    .background(Color.sttGray)
                    .foregroundColor(.gray)
                    .clipShape(Circle())
            }
            .padding(.bottom, 7 + (edges?.bottom ?? 0))
            .padding(.horizontal)
            .opacity(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .onReceive(publisher.autoScrollDidStart) { state in
            isScrolling = state
        }
        .onReceive(publisher.autoScrollDidStop) { _ in
            isScrolling = false
        }
    }

    func action() {
        publisher.autoScrollDidStart.send(!isScrolling)
    }
}
