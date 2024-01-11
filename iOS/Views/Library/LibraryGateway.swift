//
//  LibraryGateway.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-15.
//

import SwiftUI

struct LibraryGatewayView: View {
    @AppStorage(STTKeys.UseCompactLibraryView) var useCompactView = false
    var body: some View {
        SmartNavigationView {
            Group {
                if useCompactView {
                    CompactLibraryView()
                } else {
                    LibraryView()
                }
            }
        }
        .protectContent()
    }
}
