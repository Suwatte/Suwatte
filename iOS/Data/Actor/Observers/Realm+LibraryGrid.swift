//
//  Realm+LibraryGrid.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-29.
//

import Foundation
import RealmSwift

struct LibraryGridState {
    let collection: LibraryCollection?
    let readingFlag: LibraryFlag?
    let query: String
    let sort: LibraryView.LibraryGrid.KeyPath
    let order: LibraryView.LibraryGrid.SortOrder
    let filterByDownloadedTitles: Bool
    let filterByTrackedTitles: Bool
    let titlePinningType: TitlePinningType?

    func getTitlePinningType() -> TitlePinningType? {
        // Collection settings takes priority
        if let collection, collection.pinningType != nil && collection.pinningType != TitlePinningType.none {
            return collection.pinningType
        }

        // Global setting
        if let titlePinningType, titlePinningType != TitlePinningType.none {
            return titlePinningType
        }

        return nil
    }
}

extension RealmActor {

    func getLibraryEntries(state: LibraryGridState) -> Results<LibraryEntry> {
        let tracked = realm
            .objects(TrackerLink.self)
            .where { !$0.isDeleted }

        let downloads = realm
            .objects(SourceDownloadIndex.self)
            .where { $0.content != nil && $0.count > 0 }

        var library = realm
            .objects(LibraryEntry.self)
            .where { $0.content != nil && $0.isDeleted == false }

        // Query For Title
        let query = state.query
        if !query.isEmpty {
            library = library
                .filter("ANY content.additionalTitles CONTAINS[cd] %@ OR content.title CONTAINS[cd] %@ OR content.summary CONTAINS[cd] %@",
                        query, query, query)
        }

        // Collection Filter
        if let collection = state.collection {
            var predicates = [NSPredicate]()

            let idPredicate = NSPredicate(format: "ANY collections CONTAINS[cd] %@", collection.id)

            predicates.append(idPredicate)

            if let filter = collection.filter {
                switch filter.adultContent {
                    case .both: break
                    case .only:
                        predicates.append(NSPredicate(format: "content.isNSFW = true"))
                    case .none:
                        predicates.append(NSPredicate(format: "content.isNSFW = false"))
                }

                if !filter.readingFlags.isEmpty {
                    let flags = filter.readingFlags.map { $0 } as [LibraryFlag]
                    predicates.append(NSPredicate(format: "flag IN %@", flags))
                }

                if !filter.statuses.isEmpty {
                    let statuses = filter.statuses.map { $0 } as [ContentStatus]
                    predicates.append(NSPredicate(format: "content.status IN %@", statuses))
                }

                if !filter.sources.isEmpty {
                    let sources = filter.sources.map { $0 } as [String]
                    predicates.append(NSPredicate(format: "content.sourceId IN %@", sources))
                }

                if !filter.textContains.isEmpty {
                    let texts = filter.textContains.map { $0 } as [String]
                    for text in texts {
                        predicates.append(NSPredicate(format: "ANY content.additionalTitles CONTAINS[cd] %@ OR content.title CONTAINS[cd] %@ OR content.summary CONTAINS[cd] %@", text, text, text))
                    }
                }

                if !filter.contentType.isEmpty {
                    let types = filter.contentType.map({ $0 }) as [ExternalContentType]
                    predicates.append(NSPredicate(format: "content.contentType IN %@", types))
                }

                if !filter.tagContains.isEmpty {
                    let tags = filter.tagContains.map { $0.lowercased() } as [String]
                    predicates.append(NSPredicate(format: "ANY content.properties.tags.label IN[cd] %@", tags))
                }
            }

            let compound = collection.filter?.logicalOperator == .or
                ? NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

            library = library
                .filter(compound)
        }

        // Reading Flag Filter
        if let readingFlag = state.readingFlag {
            library = library
                .where {
                    $0.flag == readingFlag
                }
        }

        if state.filterByDownloadedTitles {
            let ids = downloads
                .compactMap(\.content?.id) as [String]
            library = library
                .where {
                    $0.id.in(ids)
                }
        }

        if state.filterByTrackedTitles {
            let ids = tracked
                .compactMap { $0.id } as [String]
            library = library
                .where {
                    $0.id.in(ids)
                }
        }

        let ascending = state.order.ascending
        let keyPath = state.sort.path
        library = library
            .sorted(byKeyPath: keyPath, ascending: ascending)
        return library
    }

    func observeRegularLibrary(state: LibraryGridState, _ callback: @escaping Callback<[LibraryEntry]>) async -> NotificationToken {
        var library = getLibraryEntries(state: state)

        if let pinningType = state.getTitlePinningType() {
            if pinningType == .unread {
                library = library.where { $0.unreadCount == 0 }
            } else if pinningType == .updated {
                library = library.where { $0.lastUpdated <= $0.lastOpened }
            }
        }

        func didUpdate(_ results: Results<LibraryEntry>) {
            let data = results
                .freeze()
                .toArray()
            Task { @MainActor in
                callback(data)
            }
        }

        return await observeCollection(collection: library, didUpdate(_:))
    }

    func observePinnedLibrary(state: LibraryGridState, _ callback: @escaping Callback<[LibraryEntry]>) async -> NotificationToken {
        var library = getLibraryEntries(state: state)

        if let pinningType = state.getTitlePinningType() {
            if pinningType == .unread {
                library = library.where { $0.unreadCount > 0 }
            } else if pinningType == .updated {
                library = library.where { $0.lastUpdated > $0.lastOpened }
            }
        }

        func didUpdate(_ results: Results<LibraryEntry>) {
            let data = results
                .freeze()
                .toArray()
            Task { @MainActor in
                callback(data)
            }
        }

        return await observeCollection(collection: library, didUpdate(_:))
    }
}
