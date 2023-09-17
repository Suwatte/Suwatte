//
//  LocalAuthGateway.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-08.
//

import SwiftUI

struct LocalAuthGateway: ViewModifier {
    @StateObject var manager = LocalAuthManager.shared
    @AppStorage(STTKeys.LibraryAuth) var protectContent = false

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!shouldHide)
            .blur(radius: !shouldHide ? 0 : 10)
            .overlay {
                if shouldHide {
                    OVERLAY_CONTENT
                }
            }
            .onAppear {
                manager.verify()
            }
            .animation(.default, value: shouldHide)
            .animation(.default, value: manager.isExpired)
    }

    var shouldHide: Bool {
        protectContent && manager.isExpired
    }

    var OVERLAY_CONTENT: some View {
        Image(systemName: "lock.shield")
            .resizable()
            .scaledToFit()
            .padding()
            .frame(width: 70, height: 70, alignment: .center)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(Circle())
            .onTapGesture {
                manager.verify()
            }
    }

    @MainActor
    private var edges: UIEdgeInsets? {
        let window = getKeyWindow()
        return window?.safeAreaInsets
    }
}

extension View {
    @MainActor
    func protectContent() -> some View {
        modifier(LocalAuthGateway())
    }
}
