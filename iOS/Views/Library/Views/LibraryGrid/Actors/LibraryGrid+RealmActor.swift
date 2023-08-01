//
//  LibraryGrid+RealmActor.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-30.
//

import Foundation
import RealmSwift


extension LibraryView.LibraryGrid {
    final actor RealmActor {
        
        var collection: LibraryCollection?
        var readingFlag: LibraryFlag?
        // An implicitly-unwrapped optional is used here to let us pass `self` to
        // `Realm(actor:)` within `init`
        private var realm: Realm!
        private var token: NotificationToken?
        init(collection: LibraryCollection? = nil, flag: LibraryFlag? = nil) async throws {
            self.collection = collection?.freeze()
            self.readingFlag = flag
            realm = try await Realm(actor: self)
        }
        
        private var query = ""
        private var sort: KeyPath = .dateAdded
        private var order: SortOrder = .desc
        private var showOnlyDownloadedTitles = false
        typealias Result = ([LibraryEntry]) -> Void
        
        func set(_ query: String, sort: KeyPath, order: SortOrder, downloads: Bool) {
            self.query = query
            self.sort = sort
            self.order = order
            self.showOnlyDownloadedTitles = downloads
        }
        
        func stop() {
            token?.invalidate()
            token = nil
        }
        
        func observe(_ callback: @escaping Result) async {
            let downloads = realm
                .objects(SourceDownloadIndex.self)
                .where { $0.content != nil && $0.count > 0 }
            var library = realm
                .objects(LibraryEntry.self)
                .where { $0.content != nil && $0.isDeleted == false }
            
            // Query For Title
            if !query.isEmpty {
                library = library
                    .filter("ANY content.additionalTitles CONTAINS[cd] %@ OR content.title CONTAINS[cd] %@ OR content.summary CONTAINS[cd] %@",
                            query, query, query)
            }

            // Collection Filter
            if let collection {
                var predicates = [NSPredicate]()

                let idPredicate = NSPredicate(format: "ANY collections CONTAINS[cd] %@", collection.id)

                predicates.append(idPredicate)

                if let filter = collection.filter {
                    switch filter.adultContent {
                    case .both: break
                    case .only:
                        predicates.append(NSPredicate(format: "content.adultContent = true"))
                    case .none:
                        predicates.append(NSPredicate(format: "content.adultContent = false"))
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
                        //                        let types = filter.contentType.map({ $0 }) as [ExternalContentType]
                    }

                    if !filter.tagContains.isEmpty {
                        let tags = filter.tagContains.map { $0.lowercased() } as [String]
                        predicates.append(NSPredicate(format: "ANY content.properties.tags.label IN[cd] %@", tags))
                    }
                }

                let compound = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                library = library
                    .filter(compound)
            }

            // Reading Flag Filter
            if let readingFlag {
                library = library
                    .where {
                        $0.flag == readingFlag
                    }
            }

            if showOnlyDownloadedTitles {
                let ids = downloads
                    .compactMap(\.content?.id) as [String]
                library = library
                    .where {
                        $0.id.in(ids)
                    }
            }

            let ascending = order.ascending
            let keyPath = sort.path
            library = library
                .sorted(byKeyPath: keyPath, ascending: ascending)

            token = await library.observe(on: self, { _, results in
                switch results {
                case .error(let error):
                    Logger.shared.error(error, "RealmActor")
                case .initial(let results):
                    let data = results.freeze().toArray()
                    Task { @MainActor in
                        callback(data)
                    }
                case .update(let results, deletions: _, insertions: _, modifications: _):
                    let data = results.freeze().toArray()
                    Task { @MainActor in
                        callback(data)
                    }
                }
            })
        }
    }
}
