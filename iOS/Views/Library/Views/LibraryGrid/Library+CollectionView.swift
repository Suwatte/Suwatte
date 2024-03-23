//
//  Library+CollectionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-22.
//

import RealmSwift
import SwiftUI

extension LibraryView {
    struct LibraryGrid: View {
        var useLibrary = false
        @State var presentCollectionSheet = false

        @StateObject private var model: ViewModel
        // Defaults
        @AppStorage(STTKeys.LibraryGridSortKey) private var sortKey: KeyPath = .name
        @AppStorage(STTKeys.LibraryGridSortOrder) private var sortOrder: SortOrder = .asc
        @AppStorage(STTKeys.ShowOnlyDownloadedTitles) private var showDownloadsOnly = false
        // State
        @State private var presentOptionsSheet = false
        @State private var presentMigrateSheet = false
        @State private var presentStatsSheet = false
        @AppStorage(STTKeys.UseCompactLibraryView) private var useCompactView = false

        @EnvironmentObject private var stateManager: StateManager

        private var collections: [LibraryCollection]? {
            if model.readingFlag == nil {
                return stateManager.collections
            }
            return nil
        }
        
        private var readingFlag : LibraryFlag? {
            model.readingFlag
        }
        
        private var colleciton: LibraryCollection? {
            model.collection
        }
        
        
        init(collection: LibraryCollection?, readingFlag: LibraryFlag?, useLibrary: Bool = false) {
            let m = ViewModel()
            m.setFilterGroups(collection: collection, readingFlag: readingFlag)
            self._model = StateObject(wrappedValue: m)
            self.useLibrary = useLibrary
        }

        private func observe(_: AnyHashable? = nil) {
            model.observe(downloadsOnly: showDownloadsOnly, key: sortKey, order: sortOrder)
        }

        var body: some View {
            ZStack {
                if let library = model.library {
                    if library.isEmpty {
                        No_ENTRIES
                    } else {
                        MainView(library)
                            .onChange(of: sortKey, perform: observe)
                            .onChange(of: sortOrder, perform: observe)
                            .onChange(of: showDownloadsOnly, perform: observe)
                    }
                } else {
                    ProgressView()
                }
            }
            .onChange(of: model.readingFlag, perform: observe)
            .onChange(of: model.collection, perform: observe)
            .task {
                observe()
            }
            .onDisappear {
                model.disconnect()
            }
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

                            Menu("More") {
                                Button {
                                    presentOptionsSheet.toggle()
                                } label: {
                                    Label("Settings", systemImage: "gearshape")
                                }

                                Button {
                                    presentStatsSheet.toggle()
                                } label: {
                                    Label("Statistics", systemImage: "chart.bar")
                                }

                                Button {
                                    presentMigrateSheet.toggle()
                                } label: {
                                    Label("Migrate", systemImage: "shippingbox")
                                }
                            }

                            Button {
                                Task {
                                    model.refresh()
                                }
                            } label: {
                                Label("Refresh Database", systemImage: "arrow.triangle.2.circlepath")
                            }

                            // Compact Library Helpers
                            Divider()

                            if useCompactView {
                                Button { useCompactView.toggle() } label: {
                                    Label("Standard Library", systemImage: "list.bullet.clipboard")
                                }

                                Button { presentCollectionSheet.toggle() } label: {
                                    Label("Manage Collections", systemImage: "tray.full")
                                }
                            }

                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .imageScale(.large)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .conditional(useCompactView, transform: { view in
                view
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            CollectionSelectorHeader
                        }
                    }
            })
            .navigationBarTitle(NAV_TITLE)
            .environmentObject(model)
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search \(NAV_TITLE)"))
            .onReceive(model.$query.debounce(for: .seconds(0.15), scheduler: DispatchQueue.main).dropFirst()) { _ in
                observe()
            }
            .sheet(isPresented: $presentOptionsSheet) {
                OptionsSheet(collection: model.collection)
            }
            .sheet(isPresented: $presentStatsSheet, content: {
                SmartNavigationView {
                    LoadableStatisticsView()
                }
            })
            .fullScreenCover(isPresented: $presentMigrateSheet, content: {
                PreMigrationView()
            })
            .sheet(isPresented: $presentCollectionSheet) {
                ManageCollectionsView()
            }
        }

        private var NAV_TITLE: String {
            useLibrary ? "Library" : model.collection?.name ?? model.readingFlag?.description ?? "All Titles"
        }

        private func MainView(_ entries: [LibraryEntry]) -> some View {
            LibraryGrid.Grid(entries: entries, collection: $model.collection)
                .modifier(CollectionModifier(selection: $model.navSelection))
                .modifier(SelectionModifier(entries: entries))
                .environment(\.libraryIsSelecting, model.isSelecting)
                .animation(.default, value: entries)
        }

        private var CollectionSelectorHeader: some View {
            Menu {
                
                Section {
                    Button("All Titles") {
                        if readingFlag != nil {
                            self.model.readingFlag = nil
                        } else {
                            self.model.collection = nil
                        }
                    }
                }

                
                Divider()
                
                Section {
                    if let collections = self.collections {
                        ForEach(collections) { coll in
                            Button(coll.name) {
                                self.model.collection = coll
                            }
                        }
                    }
                } header: {
                    Text("Collections")
                }

                Divider()
                
                Menu {
                    Section {
                        ForEach(LibraryFlag.allCases) { flag in
                            Button(flag.description) {
                                self.model.readingFlag = flag
                            }
                        }
                    }
                } label: {
                    Label("Reading Flags", systemImage: "flag")
                }
            } label: {
                HStack {
                    Button {} label: {
                        Text(self.model.collection?.name ?? NAV_TITLE)
                            .bold()
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(Color(UIColor.label))
                }
            }
        }

        private var No_ENTRIES: some View {
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
        }

        private func ViewTitle(count: Int) -> String {
            let selectionCount = model.isSelecting ? model.selectedIndexes.count : count
            let selectionString = model.isSelecting ? "Selection" : "Title"
            return "^[\(selectionCount) \(selectionString)](inflect: true)"
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
        case name, updateCount, dateAdded, lastUpdated, lastRead, unreadCount

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
            case .unreadCount: return "Unread Count"
            }
        }

        var path: String {
            switch self {
            case .name: return "content.title"
            case .updateCount: return "updateCount"
            case .dateAdded: return "dateAdded"
            case .lastUpdated: return "lastUpdated"
            case .lastRead: return "lastRead"
            case .unreadCount: return "unreadCount"
            }
        }
    }
}
