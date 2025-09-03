//
//  ReadLater+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-06.
//

import Combine
import Foundation
import RealmSwift
import SwiftUI

extension LibraryView.ReadLaterView {
    final class ViewModel: ObservableObject {
        @Published var query = "" {
            didSet {
                obs()
            }
        }

        @Published var ascending = false {
            didSet {
                obs()
            }
        }

        @Published var sort = ContentSort.dateAdded {
            didSet {
                obs()
            }
        }

        @Published var library = Set<String>()
        @Published var libraryLinked = Set<String>()
        @Published var readLater = [ReadLater]()

        @Published var initialFetchComplete = false
        @Published var selection: HighlightIdentifier?

        private var libraryNotificationToken: NotificationToken?
        private var libraryLinkedNotificationToken: NotificationToken?
        private var readLaterNotificationToken: NotificationToken?

        func obs() {
            Task {
                await observe()
            }
        }

        func observe() async {
            await MainActor.run { [weak self] in
                self?.disconnect()
            }
            let actor = await RealmActor.shared()
            libraryNotificationToken = await actor
                .observeLibraryIDs { values in
                    Task { @MainActor [weak self] in
                        self?.library = values
                    }
                }

            readLaterNotificationToken = await actor
                .observeReadLater(query: query,
                                  ascending: ascending,
                                  sort: sort)
                { values in
                    Task { @MainActor [weak self] in
                        self?.readLater = values
                        self?.initialFetchComplete = true
                    }
                }

            libraryLinkedNotificationToken = await actor
                .observeLinkedIDs { values in
                    Task { @MainActor [weak self] in
                        self?.libraryLinked = values
                    }
                }
        }

        func disconnect() {
            libraryNotificationToken?.invalidate()
            libraryNotificationToken = nil

            libraryLinkedNotificationToken?.invalidate()
            libraryLinkedNotificationToken = nil

            readLaterNotificationToken?.invalidate()
            readLaterNotificationToken = nil
        }
    }
}
