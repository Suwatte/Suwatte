//
//  LibraryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import RealmSwift
import SwiftUI

struct LibraryView: View {
    @AppStorage(STTKeys.LibrarySections) var sections: [LibrarySectionOrder] = [.local, .lists, .collections, .flags]
    @StateObject var AuthProvider = LocalAuthManager.shared
    @State var presentCollectionSheet = false
    @State var presentOrderSheet = false
    @State var isActive = false
    @AppStorage(STTKeys.OpenAllTitlesOnAppear) var openAllOnAppear = false
    @AppStorage(STTKeys.LibraryAuth) var requireAuth = false
    var body: some View {
        NavigationView {
            List {
                ForEach(sections, id: \.rawValue) { section in
                    section.sectionView(firstCollection: $isActive, presentCollections: $presentCollectionSheet)
                }
            }
            .navigationTitle("Library")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("\(Image(systemName: "ellipsis.circle"))") {
                        presentOrderSheet.toggle()
                    }
                    .disabled(requireAuth && AuthProvider.isExpired)
                }

            })
            .sheet(isPresented: $presentOrderSheet, content: {
                NavigationView {
                    LibrarySectionOrderSheet()
                        .environment(\.editMode, .constant(.active))
                        .navigationTitle("Library Sections")
                        .navigationBarTitleDisplayMode(.inline)
                        .closeButton()
                }
                .navigationViewStyle(.stack)

            })
        }
        .onAppear {
            if requireAuth && !LocalAuthManager.shared.isExpired {
                return
            }

            if openAllOnAppear {
                isActive.toggle()
            }
        }

        .protectContent()
    }
}

extension LibraryView {
    enum LibrarySectionOrder: Int, CaseIterable, Codable {
        case local, lists, collections, flags
        //        case anilist, mal

        var description: String {
            switch self {
            case .local:
                return "Local Content"
            case .lists:
                return "Lists"
            case .collections:
                return "Collections"
            case .flags:
                return "Reading Flags"
                //                case .anilist:
                //                    return "Anilist"
                //                case .mal:
                //                    return "MyAnimeList"
            }
        }

        @ViewBuilder
        func sectionView(firstCollection: Binding<Bool>, presentCollections: Binding<Bool>) -> some View {
            switch self {
            case .local:
                Section {
                    NavigationLink(destination: LocalContentView()) {
                        Label("On My \(UIDevice.current.model)", systemImage: UIDevice.current.model.lowercased())
                    }
                    NavigationLink(destination: OPDSView()) {
                        Label("OPDS", systemImage: "server.rack")
                    }
                } header: {
                    Text("Local")
                }
                .headerProminence(.increased)
            case .lists:
                Section {
                    NavigationLink(destination: ReadLaterView()) {
                        Label("Saved For Later", systemImage: "clock.arrow.circlepath")
                    }
                    NavigationLink(destination: HistoryView()) {
                        Label("Reading History", systemImage: "clock")
                    }

//                    NavigationLink(destination: UpdateFeedView()) {
//                        Label("Update Feed", systemImage: "bell")
//                    }
                    NavigationLink(destination: DownloadsView()) {
                        Label("Downloads", systemImage: "square.and.arrow.down")
                    }

                } header: {
                    Text("Lists")
                }
                .headerProminence(.increased)
            case .collections:
                CollectionsSectionView(isActive: firstCollection, presentCollections: presentCollections)
            case .flags:
                Section {
                    ForEach(LibraryFlag.allCases) { flag in
                        NavigationLink {
                            LibraryGrid(readingFlag: flag)
                        } label: {
                            Label(flag.description, systemImage: "flag")
                        }
                    }
                } header: {
                    Text("Reading Flags")
                }
                .headerProminence(.increased)
            }
        }
    }

    struct CollectionsSectionView: View {
        @ObservedResults(LibraryCollection.self, sortDescriptor: SortDescriptor(keyPath: "order", ascending: true)) var collections

        @Binding var isActive: Bool
        @Binding var presentCollections: Bool

        var body: some View {
            Section {
                NavigationLink(destination: LibraryGrid(), isActive: $isActive) {
                    Label("All Titles", systemImage: "folder")
                }
                ForEach(collections) { collection in
                    NavigationLink(destination: LibraryGrid(collection: collection)) {
                        Label(collection.name, systemImage: "archivebox")
                    }
                }
            } header: {
                HStack {
                    Text("Collections")
                    Spacer()
                    Button { presentCollections.toggle() }
                label: { Image(systemName: "ellipsis") }
                }
            }
            .headerProminence(.increased)
            .sheet(isPresented: $presentCollections) {
                ManageCollectionsView()
            }
        }
    }
}

extension LibraryView {
    struct LibrarySectionOrderSheet: View {
        @AppStorage(STTKeys.LibrarySections) var sections = LibraryView.LibrarySectionOrder.allCases

        var availableSections: [LibraryView.LibrarySectionOrder] {
            LibraryView.LibrarySectionOrder.allCases.filter { !sections.contains($0) }
        }

        var body: some View {
            List {
                Section {
                    ForEach(sections, id: \.hashValue) { section in
                        Text(section.description)
                    }
                    .onMove(perform: { source, destination in
                        sections.move(fromOffsets: source, toOffset: destination)
                    })
                    .onDelete { indexSet in
                        sections.remove(atOffsets: indexSet)
                    }
                } header: {
                    Text("Active")
                }

                Section {
                    ForEach(availableSections, id: \.hashValue) { section in
                        HStack {
                            ZStack {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.white)
                                    .padding(.leading, 0)
                                    .font(.system(size: 18))
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                    .padding(.leading, 0)
                                    .font(.system(size: 18))
                            }

                            Text(section.description)
                                .padding(.leading, 8.0)
                        }.onTapGesture(count: 1, perform: {
                            withAnimation {
                                sections.append(section)
                            }
                        })
                        .frame(height: 32.0)
                    }

                } header: {
                    Text("Available Sections")
                }
            }
        }
    }
}
