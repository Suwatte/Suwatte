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
        @AppStorage(STTKeys.LibraryPinningType) var pinningType: TitlePinningType = .unread
        @AppStorage(STTKeys.LibraryEnableTitlePinning) var isTitlePinningEnabled = false
        @AppStorage(STTKeys.ShowOnlyDownloadedTitles) private var showDownloadsOnly = false
        @AppStorage(STTKeys.FilterByTrackedTitles) private var filterByTrackedTitles = false
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

        private var readingFlag: LibraryFlag? {
            model.readingFlag
        }

        private var regularLibrary: [LibraryEntry] {
            model.regularLibrary ?? []
        }

        private var pinnedLibrary: [LibraryEntry] {
            model.pinnedLibrary ?? []
        }

        init(collection: LibraryCollection?, readingFlag: LibraryFlag?, useLibrary: Bool = false) {
            let m = ViewModel()
            m.setFilterGroups(collection: collection, readingFlag: readingFlag)
            _model = StateObject(wrappedValue: m)
            self.useLibrary = useLibrary
        }

        private func refreshCollection() {
            guard let currentCollection = model.collection else {
                return
            }

            model.collection = collections?.first { $0.id == currentCollection.id }
        }

        private func observe(_: AnyHashable? = nil) {
            model.observe(filterByDownloadedTitles: showDownloadsOnly, filterByTrackedTitles: filterByTrackedTitles, key: sortKey, order: sortOrder, pinningType: isTitlePinningEnabled ? pinningType : nil)
        }

        var content: some View {
            ZStack {
                if !model.isLibraryStillLoading() {
                    if regularLibrary.isEmpty && pinnedLibrary.isEmpty {
                        No_ENTRIES
                    } else {
                        LibraryGrid.Grid()
                            .modifier(SelectionModifier(regularEntries: regularLibrary, pinnedEntries: pinnedLibrary))
                            .environment(\.libraryIsSelecting, model.isSelecting)
                            .animation(.default, value: regularLibrary)
                            .animation(.default, value: pinnedLibrary)
                            .onChange(of: sortKey, perform: observe)
                            .onChange(of: sortOrder, perform: observe)
                    }

                } else {
                    ProgressView()
                }
            }
            .modifier(CollectionModifier(selection: $model.navSelection))
            .onChange(of: filterByTrackedTitles, perform: observe)
            .onChange(of: showDownloadsOnly, perform: observe)
            .onChange(of: isTitlePinningEnabled, perform: observe)
            .onChange(of: pinningType, perform: observe)
            .onChange(of: model.readingFlag, perform: observe)
            .onChange(of: model.collection, perform: observe)
            .onChange(of: stateManager.collections, perform: observe)
        }

        var body: some View {
            content
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
                            NavMenu
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
                .sheet(isPresented: $presentOptionsSheet, onDismiss: { refreshCollection() }) {
                    SmartNavigationView {
                        OptionsSheet()
                            .environmentObject(model)
                    }
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

        @ViewBuilder
        private var NavMenu: some View {
            Menu {
                Section {
                    ForEach(KeyPath.allCases) { path in
                        Button {
                            withAnimation {
                                self.sortKey = path
                            }
                        } label: {
                            HStack {
                                Text(path.description)
                                Spacer()
                                if self.sortKey == path {
                                    Image(systemName: "checkmark")
                                        .transition(.scale)
                                }
                            }
                        }
                        .tag(path)
                    }
                } header: {
                    Text("Sort By")
                }

                Button {
                    sortOrder.toggle()

                } label: {
                    Label("Order", systemImage: sortOrder.ascending ? "arrow.down" : "arrow.up")
                        .transition(.scale)
                }

                Section {
                    Button {
                        withAnimation {
                            self.showDownloadsOnly = !self.showDownloadsOnly
                        }
                    } label: {
                        HStack {
                            Text("Downloaded")
                            Spacer()
                            if self.showDownloadsOnly {
                                Image(systemName: "checkmark")
                                    .transition(.scale)
                            }
                        }
                    }
                    Button {
                        withAnimation {
                            self.filterByTrackedTitles = !self.filterByTrackedTitles
                        }
                    } label: {
                        HStack {
                            Text("Tracked")
                            Spacer()
                            if self.filterByTrackedTitles {
                                Image(systemName: "checkmark")
                                    .transition(.scale)
                            }
                        }
                    }
                } header: {
                    Text("Filter By")
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .imageScale(.large)
            }

            Menu {
                // Select
                Button {
                    model.isSelecting = true
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }

                Divider()

                if useCompactView {
                    Button { useCompactView.toggle() } label: {
                        Label("Standard Library", systemImage: "list.bullet.clipboard")
                    }

                    Divider()
                }

                Button {
                    presentOptionsSheet.toggle()
                } label: {
                    Label("Edit Collection", systemImage: "gearshape")
                }

                Button { presentCollectionSheet.toggle() } label: {
                    Label("Manage Collections", systemImage: "tray.full")
                }

                Divider()

                Button {
                    Task {
                        model.refresh()
                    }
                } label: {
                    Label("Refresh Database", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    presentMigrateSheet.toggle()
                } label: {
                    Label("Migrate", systemImage: "shippingbox")
                }

                Button {
                    presentStatsSheet.toggle()
                } label: {
                    Label("Statistics", systemImage: "chart.bar")
                }

            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
            }
        }

        private var NAV_TITLE: String {
            useLibrary ? "Library" : model.collection?.name ?? model.readingFlag?.description ?? "All Titles"
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

                if showDownloadsOnly || filterByTrackedTitles || self.model.collection?.filter != nil {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .frame(width: 20, height: 20, alignment: .center)
                            .scaledToFit()
                            .foregroundColor(.yellow)
                        Text("One or multiple filters are applied")
                            .fontWeight(.light)
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
            }
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
