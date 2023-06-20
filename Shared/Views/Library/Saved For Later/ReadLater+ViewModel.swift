//
//  ReadLater+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-06.
//

import Combine
import Foundation
import RealmSwift

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

        @Published var library: Results<LibraryEntry>?
        @Published var readLater: Results<ReadLater>?

        private var libraryNotificationToken: NotificationToken?
        private var readLaterNotificationToken: NotificationToken?

        func observe() {
            let realm = try! Realm()

            let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
            libraryNotificationToken = realm
                .objects(LibraryEntry.self)
                .where { $0.content != nil && $0.isDeleted == false }
                .observe { [weak self] result in
                    switch result {
                    case let .error(error):
                        Logger.shared.error("\(error)")
                    case let .initial(results):
                        self?.library = results.freeze()
                    case let .update(results, _, _, _):
                        self?.library = results.freeze()
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
                .observe { [weak self] result in
                    switch result {
                    case let .error(error):
                        Logger.shared.error("\(error)")
                    case let .initial(results):
                        self?.readLater = results.freeze()
                    case let .update(results, _, _, _):
                        self?.readLater = results.freeze()
                    }
                }
        }

        func disconnect() {
            libraryNotificationToken?.invalidate()
            libraryNotificationToken = nil

            readLaterNotificationToken?.invalidate()
            readLaterNotificationToken = nil
        }

        func refresh() {
            guard let library = library else {
                return
            }
            let targets = library.compactMap { $0.content }.map { ($0.contentId, $0.sourceId) } as [(String, String)]
            ToastManager.shared.loading = true
            Task {
                for content in targets {
                    await DataManager.shared.refreshStored(contentId: content.0, sourceId: content.1)
                }
                await MainActor.run {
                    ToastManager.shared.loading = false
                    ToastManager.shared.info("Database Refreshed Successfully")
                }
            }
        }

        var isLoading: Bool {
            library == nil || readLater == nil
        }
    }
}
