//
//  CompactLibraryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-15.
//

import SwiftUI

struct CompactLibraryView: View {
    @AppStorage(STTKeys.OpenDefaultCollection) var defaultCollectionToOpen = ""
    @AppStorage(STTKeys.OpenDefaultCollectionEnabled) var openDefaultCollectionOnAppear = false

    @StateObject var appState = StateManager.shared

    var body: some View {
        ZStack {
            if appState.isCollectionInitialized() {
                let collectionToOpen: LibraryCollection? = openDefaultCollectionOnAppear ? StateManager.shared.collections.first { $0.id == defaultCollectionToOpen } : nil

                LibraryView.LibraryGrid(collection: collectionToOpen, readingFlag: nil, useLibrary: true)
            } else {
                ProgressView()
            }
        }
    }
}
