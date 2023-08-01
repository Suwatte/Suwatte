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
        @StateObject var model: ViewModel
        // Defaults
        @AppStorage(STTKeys.LibraryGridSortKey) var sortKey: KeyPath = .name
        @AppStorage(STTKeys.LibraryGridSortOrder) var sortOrder: SortOrder = .asc
        @AppStorage(STTKeys.ShowOnlyDownloadedTitles) var showDownloadsOnly = false
        // State
        @State var presentOrderOptions = false
        @State var presentMigrateSheet = false

        @ViewBuilder
        func conditional() -> some View {
            Group {
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
        }

        func observe(_: AnyHashable? = nil) {
            model.observe(downloadsOnly: showDownloadsOnly, key: sortKey, order: sortOrder)
        }

        var body: some View {
            conditional()
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

                                Button {
                                    model.presentOptionsSheet.toggle()
                                } label: {
                                    Label("Settings", systemImage: "gearshape")
                                }

                                Button {
                                    presentMigrateSheet.toggle()
                                } label: {
                                    Label("Migrate", systemImage: "shippingbox")
                                }

                                Button {
                                    Task {
                                        model.refresh()
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
                    OptionsSheet(collection: model.collection)
                }
                .fullScreenCover(isPresented: $presentMigrateSheet, content: {
                    PreMigrationView()
                })
                .navigationTitle(NAV_TITLE)
                .navigationBarTitleDisplayMode(.inline)
                .environmentObject(model)
                .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search \(NAV_TITLE)"))
                .onReceive(model.$query.debounce(for: .seconds(0.15), scheduler: DispatchQueue.main).dropFirst()) { _ in
                    observe()
                }
        }

        var NAV_TITLE: String {
            model.collection?.name ?? model.readingFlag?.description ?? "All Titles"
        }

        func MainView(_ entries: [LibraryEntry]) -> some View {
            LibraryGrid.Grid(entries: entries, collection: model.collection)
                .modifier(CollectionModifier(selection: $model.navSelection))
                .modifier(SelectionModifier(entries: entries))
                .environment(\.libraryIsSelecting, model.isSelecting)
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
