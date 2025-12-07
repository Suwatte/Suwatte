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
                    clearSelection()
                }
            }
        }

        @Published var selectedPinnedIndexes: Set<Int> = []
        @Published var selectedRegularIndexes: Set<Int> = []
        @Published var navSelection: LibraryEntry?
        @Published var query = ""
        @Published var regularLibrary: [LibraryEntry]?
        @Published var pinnedLibrary: [LibraryEntry]?
        private var regularLibraryToken: NotificationToken?
        private var pinnedLibraryToken: NotificationToken?
        private var didSet = false

        func setFilterGroups(collection: LibraryCollection? = nil, readingFlag: LibraryFlag? = nil) {
            guard !didSet else {
                return
            }
            self.collection = collection
            self.readingFlag = readingFlag
        }

        func disconnect() {
            regularLibraryToken?.invalidate()
            regularLibraryToken = nil
            pinnedLibraryToken?.invalidate()
            pinnedLibraryToken = nil
        }

        func clearSelection() {
            selectedPinnedIndexes.removeAll()
            selectedRegularIndexes.removeAll()
        }

        func isLibraryStillLoading() -> Bool {
            regularLibrary == nil || pinnedLibrary == nil
        }

        func observe(filterByDownloadedTitles: Bool, filterByTrackedTitles: Bool, key: KeyPath, order: SortOrder, pinningType: TitlePinningType? = nil) {
            disconnect()
            let state: LibraryGridState = .init(collection: collection?.freeze(),
                                                readingFlag: readingFlag,
                                                query: query,
                                                sort: key,
                                                order: order,
                                                filterByDownloadedTitles: filterByDownloadedTitles,
                                                filterByTrackedTitles: filterByTrackedTitles,
                                                titlePinningType: pinningType)
            Task { @MainActor in
                let actor = await RealmActor.shared()
                regularLibraryToken = await actor
                    .observeRegularLibrary(state: state) { [weak self] result in
                        withAnimation {
                            self?.regularLibrary = result
                        }
                    }

                if state.getTitlePinningType() != nil {
                    pinnedLibraryToken = await actor
                        .observePinnedLibrary(state: state) { [weak self] result in
                            withAnimation {
                                self?.pinnedLibrary = result
                            }
                        }
                } else {
                    pinnedLibraryToken?.invalidate()
                    pinnedLibraryToken = nil
                    pinnedLibrary = []
                }
            }
        }

        func refresh() {
            guard let regularLibrary, let pinnedLibrary else {
                return
            }

            if pinnedLibrary.isEmpty, regularLibrary.isEmpty {
                return
            }

            ToastManager.shared.info("Refreshing Database.")

            Task { [regularLibrary, pinnedLibrary] in
                let actor = await Suwatte.RealmActor.shared()
                for content in (regularLibrary + pinnedLibrary).compactMap(\.content) {
                    await actor.refreshStored(contentId: content.contentId, sourceId: content.sourceId)
                }
                ToastManager.shared.info("Database Refreshed")
            }
        }
    }
}
