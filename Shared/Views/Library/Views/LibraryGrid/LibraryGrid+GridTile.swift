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
        @AppStorage(STTKeys.LibraryShowBadges) var showBadges = true
        @AppStorage(STTKeys.LibraryBadgeType) var badgeType = LibraryBadge.update
        @EnvironmentObject var model: ViewModel

        var body: some View {
            ZStack(alignment: .topTrailing) {
                DefaultTile(entry: entry.content!.toHighlight(), sourceId: entry.content?.sourceId)
                if showBadges && !model.isSelecting {
                    InfoOverlay
                }
            }
        }

        @ViewBuilder
        var InfoOverlay: some View {
            switch badgeType {
            case .unread:
                if entry.unreadCount >= 1 {
                    CapsuleBadge(text: min(entry.unreadCount, 999).description)
                }
            case .update:
                if entry.updateCount >= 1 {
                    CapsuleBadge(text: min(entry.updateCount, 999).description)
                }
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
