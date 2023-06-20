//
//  LocalContentView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-07.
//

import RealmSwift
import SwiftUI

struct LocalContentView: View {
    @ObservedObject var model = LocalContentManager.shared
    @AppStorage(STTKeys.LocalSortLibrary) var sortSelection = LocalContentManager.Book.sortOptions.creationDate
    @AppStorage(STTKeys.LocalOrderLibrary) var isDescending = true

    @State var text = ""
    @State var presentFilterSheet = false
    @State var presentImporter = false
    @State var presentSettings = false
    @State var presentDownloadQueue = false
    @State var isSelecting = false

    var body: some View {
        Grid(data: filteredAndSorted, isSelecting: $isSelecting)
            .environment(\.libraryIsSelecting, isSelecting)

            .navigationTitle("Local Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isSelecting {
                        MenuButton
                    } else {
                        Button("Done") {
                            isSelecting = false
                        }
                    }
                }
            }
            .sheet(isPresented: $presentSettings, content: {
                NavigationView {
                    SetttingsSheet()
                        .navigationBarTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .closeButton()
                }
            })
            .task {
                model.observe()
            }
            .onDisappear {
                model.stopObserving()
            }
            .modifier(OpenLocalModifier(isPresenting: $presentImporter))
            .environmentObject(model)
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Library")
            .sheet(isPresented: $presentDownloadQueue, content: {
                LCV_Download()
            })
            .animation(.default, value: isSelecting)
            .animation(.default, value: model.idHash)
            .animation(.default, value: text)
            .animation(.default, value: isDescending)
            .animation(.default, value: sortSelection)
    }

    var filteredAndSorted: [LocalContentManager.Book] {
        let results = model.idHash.values.compactMap { $0 }
            .filter { text.isEmpty ? true : $0.title.lowercased().contains(text.lowercased()) }
            .sorted { lhs, rhs in
                switch sortSelection {
                case .creationDate:
                    return nullableDate(lhs.fileCreationDate) < nullableDate(rhs.fileCreationDate)
                case .size:
                    return STTHelpers.optionalCompare(firstVal: lhs.fileSize, secondVal: rhs.fileSize)
                case .title:
                    return lhs.title < rhs.title
                case .type:
                    return lhs.fileExt < rhs.fileExt
                case .year:
                    return STTHelpers.optionalCompare(firstVal: lhs.year, secondVal: rhs.year)
                case .dateAdded:
                    return nullableDate(lhs.dateAdded) < nullableDate(rhs.dateAdded)
                case .lastRead:
                    return dateOfMarker(id: lhs.id) < dateOfMarker(id: rhs.id)
                }
            }

        if isDescending {
            return results.reversed()
        }

        return results
    }

    func nullableDate(_ date: Date?) -> Date {
        date ?? .distantPast
    }

    func dateOfMarker(id _: Int64) -> Date {
        .distantPast
    }

    @ViewBuilder
    var MenuButton: some View {
        Menu {
            Button {
                presentImporter.toggle()
            } label: {
                Label("Import Files", systemImage: "plus")
            }

            // TODO: Flesh out selection
            //            Button { isSelecting.toggle() } label: {
            //                Label("Select", systemImage: "checkmark.circle")
            //            }

            Divider()
            Picker("Sort Library", selection: $sortSelection) {
                ForEach(LocalContentManager.Book.sortOptions.allCases, id: \.hashValue) { option in

                    HStack {
                        Text(option.description)
                        Spacer()
                    }
                    .tag(option)
                }
            }
            .pickerStyle(.menu)

            Picker("Order Library", selection: $isDescending) {
                Text("Ascending")
                    .tag(false)
                Text("Descending")
                    .tag(true)
            }
            .pickerStyle(.menu)
            Divider()
            Button {
                presentDownloadQueue.toggle()
            } label: {
                Label("Download Queue", systemImage: "square.and.arrow.down")
            }
            Button {
                presentSettings.toggle()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
