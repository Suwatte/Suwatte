//
//  LibraryGateway.swift
//  Suwatte (iOS)
//
//  Created by Seyden on 13.01.25.
//

import SwiftUI

struct LibraryGateway: View {
    @AppStorage(STTKeys.UseCompactLibraryView) var useCompactView = false

    var body: some View {
        if useCompactView {
            CompactLibraryView()
        } else {
            LibraryView()
        }
    }
}
