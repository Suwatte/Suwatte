//
//  LibraryGrid+GridTile.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-24.
//

import ASCollectionView
import Kingfisher
import SwiftUI

extension LibraryView.LibraryGrid {
    struct GridTile: View {
        var entry: LibraryEntry
        @AppStorage(STTKeys.ShowUpdateBadges) var showUpdateBadge = true
        @EnvironmentObject var model: ViewModel

        var body: some View {
            ZStack(alignment: .topTrailing) {
                GateWay
                InfoOverlay
            }
        }

        @ViewBuilder
        var GateWay: some View {
            if let highlight = entry.content?.toHighlight() {
                DefaultTile(entry: highlight, sourceId: entry.content?.sourceId)
            } else {
                Text("Bad Data")
            }
        }

        @ViewBuilder
        var InfoOverlay: some View {
            if !model.isSelecting && showUpdateBadge && entry.updateCount >= 1 {
                CapsuleBadge(text: min(entry.updateCount, 99).description)
            }
        }
    }
}

// MARK: Environment Key to down library state to generic tile

private struct LibraryIsSelecting: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var libraryIsSelecting: Bool {
        get { self[LibraryIsSelecting.self] }
        set { self[LibraryIsSelecting.self] = newValue }
    }
}
