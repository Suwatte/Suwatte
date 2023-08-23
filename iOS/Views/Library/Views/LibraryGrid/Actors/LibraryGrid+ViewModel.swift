//
//  LibraryGrid+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import Combine
import Foundation
import RealmSwift
import SwiftUI

extension LibraryView.LibraryGrid {
    final class ViewModel: ObservableObject {
        var collection: LibraryCollection?
        var readingFlag: LibraryFlag?
        @Published var searchQuery = ""
        // Sheets
        @Published var presentOptionsSheet = false

        // Selections
        @Published var isSelecting = false {
            didSet {
                // Clear Selections when user exits selection mode
                if !isSelecting {
                    selectedIndexes.removeAll()
                }
            }
        }

        @Published var selectedIndexes: Set<Int> = []
        @Published var navSelection: LibraryEntry?
        @Published var query = ""
        @Published var library: [LibraryEntry]?
        private var actor: RealmActor?

        init(collection: LibraryCollection? = nil, readingFlag: LibraryFlag? = nil) {
            self.collection = collection
            self.readingFlag = readingFlag
            Task {
                self.actor = try? await RealmActor()
            }
        }

        func disconnect() {
            Task {
                await actor?.stop()
            }
        }

        func didSetResult(_ lib: [LibraryEntry]) {
            withAnimation {
                self.library = lib
            }
        }

        func observe(downloadsOnly: Bool, key: KeyPath, order: SortOrder) {
            Task {
                await actor?.set(query, sort: key, order: order, downloads: downloadsOnly)
                await actor?.observe(didSetResult(_:))
            }
        }

        func refresh() {
            guard let library, !library.isEmpty else { return }
            ToastManager.shared.loading = true

            Task {
                let actor = await Suwatte.RealmActor()
                for content in library.compactMap(\.content) {
                    await actor.refreshStored(contentId: content.contentId, sourceId: content.sourceId)
                }
                ToastManager.shared.loading = false
                ToastManager.shared.info("Database Refreshed")
            }
        }
    }
}
