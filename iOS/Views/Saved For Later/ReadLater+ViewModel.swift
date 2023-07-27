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
                observe()
            }
        }

        @Published var ascending = false {
            didSet {
                observe()
            }
        }

        @Published var sort = ContentSort.dateAdded {
            didSet {
                observe()
            }
        }

        @Published var library = Set<String>()
        @Published var readLater = [ReadLater]()

        @Published var initialFetchComplete = false
        @Published var selection: HighlightIdentifier?

        private var libraryNotificationToken: NotificationToken?
        private var readLaterNotificationToken: NotificationToken?

        func observe() {
            disconnect()
            let realm = try! Realm()

            let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
            libraryNotificationToken = realm
                .objects(LibraryEntry.self)
                .where { $0.content != nil && $0.isDeleted == false }
                .observe { result in
                    switch result {
                    case let .error(error):
                        Logger.shared.error("\(error)", "ReadLater")
                    case let .initial(results):
                        let ids = Set(results.map(\.id))
                        Task { @MainActor in
                            withAnimation {
                                self.library = ids
                            }
                        }
                    case let .update(results, _, _, _):
                        let ids = Set(results.map(\.id))
                        Task { @MainActor in
                            withAnimation {
                                self.library = ids
                            }
                        }
                    }
                }

            var readL = realm
                .objects(ReadLater.self)
                .where { $0.content != nil && $0.isDeleted == false }
                .sorted(byKeyPath: sort.KeyPath, ascending: ascending)

            if !query.isEmpty {
                readL = readL.filter("ANY content.additionalTitles CONTAINS[cd] %@ OR content.title CONTAINS[cd] %@ OR content.summary CONTAINS[cd] %@", query, query, query)
            }

            readLaterNotificationToken = readL
                .observe { result in
                    switch result {
                    case let .error(error):
                        Logger.shared.error("\(error)")
                    case let .initial(results):
                        let items = results.freeze().toArray()
                        Task { @MainActor in
                            withAnimation {
                                self.readLater = items
                                if !self.initialFetchComplete {
                                    self.initialFetchComplete.toggle()
                                }
                            }
                        }
                    case let .update(results, _, _, _):
                        let items = results.freeze().toArray()
                        Task { @MainActor in
                            withAnimation {
                                self.readLater = items
                                if !self.initialFetchComplete {
                                    self.initialFetchComplete.toggle()
                                }
                            }
                        }
                    }
                }
        }

        func disconnect() {
            libraryNotificationToken?.invalidate()
            libraryNotificationToken = nil

            readLaterNotificationToken?.invalidate()
            readLaterNotificationToken = nil
        }
    }
}
