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
        @Published var collection: LibraryCollection?
        @Published var readingFlag: LibraryFlag?
        @Published var searchQuery = ""
        // Sheets

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
        private var token: NotificationToken?

        func setFilterGroups(collection: LibraryCollection? = nil, readingFlag: LibraryFlag? = nil) {
            self.collection = collection
            self.readingFlag = readingFlag
        }

        func disconnect() {
            token?.invalidate()
            token = nil
        }

        func didSetResult(_ lib: [LibraryEntry]) {
            withAnimation {
                self.library = lib
            }
        }

        func observe(downloadsOnly: Bool, key: KeyPath, order: SortOrder) {
            disconnect()
            let state: LibraryGridState = .init(collection: collection?.freeze(),
                                                readingFlag: readingFlag,
                                                query: query,
                                                sort: key,
                                                order: order,
                                                showOnlyDownloadedTitles: downloadsOnly)
            Task { @MainActor in
                token = await RealmActor
                    .shared()
                    .observeLibrary(state: state) { [weak self] result in
                        self?.didSetResult(result)
                    }
            }
        }

        func refresh() {
            guard let library, !library.isEmpty else { return }
            ToastManager.shared.info("Refreshing Database.")

            Task { [library] in
                let actor = await Suwatte.RealmActor.shared()
                for content in library.compactMap(\.content) {
                    await actor.refreshStored(contentId: content.contentId, sourceId: content.sourceId)
                }
                ToastManager.shared.info("Database Refreshed")
            }
        }
    }
}
