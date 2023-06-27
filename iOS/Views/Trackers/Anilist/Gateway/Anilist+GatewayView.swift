//
//  Anilist+GatewayView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import KeychainSwift
import SwiftUI

extension AnilistView {
    struct Gateway: View {
        var body: some View {
            if isAuthenticated {
                LoadableUserView()
            } else {
                SignInView()
            }
        }

        var isAuthenticated: Bool {
            let chain = KeychainSwift()
            chain.synchronizable = true
            return chain.get(STTKeys.anilistAccessToken) != nil
        }
    }
}
