//
//  LibraryGrid.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-22.
//

import RealmSwift
import SwiftUI

extension LibraryView {
    struct LibraryGrid: View {
        var collection: LibraryCollection?
        var readingFlag: LibraryFlag?
        @ObservedResults(LibraryEntry.self) var unfilteredEntries
        @ObservedResults(ICDMDownloadObject.self, where: { $0.status == .completed }) var downloads
        // Defaults
        @AppStorage(STTKeys.LibraryGridSortKey) var sortKey: KeyPath = .name
        @AppStorage(STTKeys.LibraryGridSortOrder) var sortOrder: SortOrder = .asc
        @AppStorage(STTKeys.ShowOnlyDownloadedTitles) var showDownloadsOnly = false
        // State
        @State var presentOrderOptions = false
        @StateObject var model: ViewModel = .init()
        @State var query = ""

        @ViewBuilder
        func conditional() -> some View {
            let filteredResult = filteredLibrary()
            if filteredResult.isEmpty {
                No_ENTRIES
            } else {
                MainView(filteredResult)
            }
        }

        var body: some View {
            conditional()
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        if model.isSelecting {
                            Button("Done") {
                                model.isSelecting = false
                            }
                        } else {
                            Menu {
                                // Select
                                Button {
                                    model.isSelecting = true
                                } label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                }
                                Divider()

                                Picker("Sort By", selection: $sortKey) {
                                    ForEach(KeyPath.allCases) { path in
                                        Button(path.description) {
                                            self.sortKey = path
                                        }
                                        .tag(path)
                                    }
                                }
                                .pickerStyle(.menu)

                                Button {
                                    sortOrder.toggle()

                                } label: {
                                    Label("Order", systemImage: "chevron.\(sortOrder.ascending ? "up" : "down")")
                                }

                                Divider()

                                Button {
                                    model.presentOptionsSheet.toggle()
                                } label: {
                                    Label("Settings", systemImage: "gearshape")
                                }
                                
                                Button {
                                    let targets = filteredLibrary().compactMap({ $0.content }).map({ ($0.contentId, $0.sourceId) }) as [(String, String)]
                                    Task {
                                        for content in targets {
                                            await DataManager.shared.refreshStored(contentId: content.0, sourceId: content.1)
                                        }
                                        await MainActor.run {
                                            ToastManager.shared.setComplete()
                                        }
                                    }
                                } label: {
                                    Label("Refresh Database", systemImage: "arrow.triangle.2.circlepath")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .imageScale(.large)
                            }
                        }
                    }
                }
                .sheet(isPresented: $model.presentOptionsSheet) {
                    OptionsSheet(collection: collection)
                }
                .environmentObject(model)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search \(NAV_TITLE)"))
        }

        var NAV_TITLE: String {
            collection?.name ?? readingFlag?.description ?? "All Titles"
        }

        func MainView(_ entries: Results<LibraryEntry>) -> some View {
            LibraryGrid.Grid(entries: entries, collection: collection)
                .modifier(CollectionModifier(selection: $model.navSelection))
                .modifier(SelectionModifier(entries: entries))
                .environment(\.libraryIsSelecting, model.isSelecting)
                .navigationTitle(NAV_TITLE)
                .navigationBarTitleDisplayMode(.inline)
                .animation(.default, value: entries)
        }

        var No_ENTRIES: some View {
            VStack {
                Text("It's empty here...")
                    .fontWeight(.light)
                    .font(.headline)
                    .foregroundColor(.gray)

                if showDownloadsOnly {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .frame(width: 20, height: 20, alignment: .center)
                            .scaledToFit()
                            .foregroundColor(.yellow)
                        Text("Showing Downloaded Titles Only")
                            .fontWeight(.light)
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle(NAV_TITLE)
            .navigationBarTitleDisplayMode(.inline)
        }

        func SortOrderView(count: Int) -> some View {
            Button {
                sortOrder.toggle()
            } label: {
                HStack {
                    Text(ViewTitle(count: count))
                    Image(systemName: sortOrder.ascending ? "chevron.up" : "chevron.down")
                }
            }

            .buttonStyle(.plain)
        }

        func ViewTitle(count: Int) -> String {
            "\(model.isSelecting ? model.selectedIndexes.count : count) \(model.isSelecting ? "Selection" : "Title")\((model.isSelecting ? model.selectedIndexes.count : count) > 1 ? "s" : "")"
        }

        func filteredLibrary() -> Results<LibraryEntry> {
            var results = unfilteredEntries
                .where { $0.content != nil }

            if !query.isEmpty {
                results = results.filter("ANY content.additionalTitles CONTAINS[cd] %@ OR content.title CONTAINS[cd] %@ OR content.summary CONTAINS[cd] %@", query, query, query)
            }

            // Collection Filter
            if let collection = collection {
                var predicates = [NSPredicate]()

                let idPredicate = NSPredicate(format: "ANY collections CONTAINS[cd] %@", collection._id)

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
//                results = results.where {
//                    $0.collections.contains(collection._id) || (
//
//                        $0.content.title.contains(collection.filter., options: )
//                    )
//                }
                results = results.filter(compound)
            }

            if let readingFlag = readingFlag {
                results = results.where {
                    $0.flag == readingFlag
                }
            }

            if showDownloadsOnly {
                let ids = downloads.compactMap { $0.chapter?.ContentIdentifer } as [String]
                results = results.where {
                    $0._id.in(ids)
                }
            }

            let ascending = sortOrder.ascending
            let keyPath = sortKey.path
            results = results.sorted(byKeyPath: keyPath, ascending: ascending)
            return results
        }
    }
}

extension LibraryView.LibraryGrid {
    enum SortOrder: Int, CaseIterable {
        case asc, desc

        var description: String {
            switch self {
            case .asc: return "Ascending"
            case .desc: return "Descending"
            }
        }

        var ascending: Bool {
            switch self {
            case .asc: return true
            case .desc: return false
            }
        }

        mutating func toggle() {
            if ascending {
                self = .desc
            } else {
                self = .asc
            }
        }
    }

    enum KeyPath: Int, CaseIterable, Identifiable {
        case name, updateCount, dateAdded, lastUpdated, lastRead

        var id: Int {
            hashValue
        }

        var description: String {
            switch self {
            case .name: return "Name"
            case .updateCount: return "Update Count"
            case .dateAdded: return "Date Added"
            case .lastUpdated: return "Last Updated"
            case .lastRead: return "Last Read"
            }
        }

        var path: String {
            switch self {
            case .name: return "content.title"
            case .updateCount: return "updateCount"
            case .dateAdded: return "dateAdded"
            case .lastUpdated: return "lastUpdated"
            case .lastRead: return "lastRead"
            }
        }
    }
}
