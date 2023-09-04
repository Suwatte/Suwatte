//
//  LibraryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import RealmSwift
import SwiftUI

struct LibraryView: View {
    @AppStorage(STTKeys.LibrarySections) var sections: [String] = DEFAULT_LIBRARY_SECTIONS
    @StateObject var AuthProvider = LocalAuthManager.shared
    @State var presentCollectionSheet = false
    @State var presentOrderSheet = false
    @State var openFirstCollection = false
    @AppStorage(STTKeys.OpenAllTitlesOnAppear) var openAllOnAppear = false
    @AppStorage(STTKeys.LibraryAuth) var requireAuth = false
    @State var runners: [StoredRunnerObject] = []
    @State var pageLinks: [String: [DSKCommon.PageLinkLabel]] = [:]
    @State var triggeredLoad = false

    var body: some View {
        NavigationView {
            List {
                ForEach(sections) { section in
                    LibrarySectionBuilder(key: section, openFirstCollection: $openFirstCollection, links: $pageLinks, runners: $runners)
                }
            }
            .refreshable {
                await loadPageLinks()
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Library")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            presentOrderSheet.toggle()
                        } label: {
                            Label("Manage Sections", systemImage: "tray.2")
                        }
                        Button {
                            presentCollectionSheet.toggle()
                        } label: {
                            Label("Manage Collections", systemImage: "tray.full")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
        .task {
            if requireAuth && !LocalAuthManager.shared.isExpired {
                return
            }

            if openAllOnAppear {
                openFirstCollection.toggle()
            }
        }
        .protectContent()
        .navigationViewStyle(.stack)
        .sheet(isPresented: $presentCollectionSheet) {
            ManageCollectionsView()
        }
        .task {
            guard !triggeredLoad else { return }
            await loadPageLinks()
        }
        .onChange(of: sections) { _ in
            Task {
                await loadPageLinks()
            }
        }
        .onReceive(StateManager.shared.runnerListPublisher) { _ in
            Task {
                await loadPageLinks()
            }
        }
    }
}

// MARK: - Section Builder

extension LibraryView {
    struct LibrarySectionBuilder: View {
        let key: String
        @Binding var openFirstCollection: Bool
        @Binding var links: [String: [DSKCommon.PageLinkLabel]]
        @Binding var runners: [StoredRunnerObject]
        var body: some View {
            Group {
                switch key {
                case "library.local":
                    LibrarySectionView()
                case "library.lists":
                    ListsSectionView()
                case "library.collections":
                    CollectionsSectionView(isActive: $openFirstCollection)
                case "library.flags":
                    FlagsSectionView()
                case "library.downloads":
                    DownloadSection()
                default:
                    if let pageLinks = links[key], let runner = runners.first(where: { $0.id == key }) {
                        PageLinkSectionView(runner: runner, pageLinks: pageLinks)
                    }
                }
            }
        }
    }
}

// MARK: PageLink Section

extension LibraryView {
    struct PageLinkSectionView: View {
        let runner: StoredRunnerObject
        let pageLinks: [DSKCommon.PageLinkLabel]

        var body: some View {
            Section {
                ForEach(pageLinks, id: \.hashValue) { pageLink in
                    NavigationLink {
                        PageLinkView(pageLink: pageLink, runnerID: runner.id)
                    } label: {
                        HStack {
                            STTThumbView(url: URL(string: pageLink.cover ?? runner.thumbnail))
                                .frame(width: 32, height: 32)
                                .cornerRadius(5)
                            Text(pageLink.title)
                            Spacer()
                        }
                    }
                }
            } header: {
                Text(runner.name)
            }
            .headerProminence(.increased)
        }
    }
}

// MARK: - Flags Section

extension LibraryView {
    struct FlagsSectionView: View {
        var body: some View {
            Section {
                ForEach(LibraryFlag.allCases) { flag in
                    NavigationLink {
                        LibraryGrid(model: .init(readingFlag: flag))
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

// MARK: - Lists Section

extension LibraryView {
    struct ListsSectionView: View {
        var body: some View {
            Section {
                NavigationLink(destination: ReadLaterView()) {
                    Label("Saved For Later", systemImage: "clock.arrow.circlepath")
                }
                NavigationLink(destination: HistoryView()) {
                    Label("Reading History", systemImage: "clock")
                }
                NavigationLink(destination: UpdateFeedView()) {
                    Label("Your Feed", systemImage: "bell")
                }
            } header: {
                Text("Lists")
            }
            .headerProminence(.increased)
        }
    }
}

// MARK: - Library Section

extension LibraryView {
    struct LibrarySectionView: View {
        var body: some View {
            Section {
                NavigationLink(destination: DirectoryViewer.Coreview()) {
                    Label("On My \(UIDevice.current.model)", systemImage: UIDevice.current.model.lowercased())
                }
                NavigationLink(destination: OPDSView()) {
                    Label("OPDS", systemImage: "server.rack")
                }
            } header: {
                Text("Local")
            }
            .headerProminence(.increased)
        }
    }
}

// MARK: - Collections Section

extension LibraryView {
    struct CollectionsSectionView: View {
        @Binding var isActive: Bool
        @EnvironmentObject private var stateManager: StateManager

        private var collections: [LibraryCollection] {
            stateManager.collections
        }
        
        var body: some View {
            Section {
                NavigationLink(destination: LibraryGrid(model: .init()), isActive: $isActive) {
                    Label("All Titles", systemImage: "folder")
                }
                ForEach(collections) { collection in
                    NavigationLink(destination: LibraryGrid(model: .init(collection: collection))) {
                        Label(collection.name, systemImage: "archivebox")
                    }
                }
            } header: {
                Text("Collections")
            }
            .headerProminence(.increased)
        }
    }
}

// MARK: - Order Sheet

extension LibraryView {
    struct LibrarySectionOrderSheet: View {
        @AppStorage(STTKeys.LibrarySections) var sections = DEFAULT_LIBRARY_SECTIONS
        @State var priviledgedRunners = [StoredRunnerObject]()
        var availableSections: [String] {
            getAvailableSections()
        }

        var body: some View {
            List {
                Section {
                    ForEach(sections, id: \.hashValue) { section in
                        Cell(section)
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

                            Cell(section)
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
            .task {
                let actor = await RealmActor.shared()
                priviledgedRunners = await actor.getLibraryPageProviders()
            }
        }

        @ViewBuilder
        func Cell(_ key: String) -> some View {
            Group {
                switch key {
                case "library.local":
                    Text("On My \(UIDevice.current.model)")
                case "library.lists":
                    Text("Lists")
                case "library.collections":
                    Text("Collections")
                case "library.flags":
                    Text("Reading Flags")
                case "library.downloads":
                    Text("Downloads")
                default:
                    if let name = priviledgedRunners.first(where: { $0.id == key })?.name {
                        Text(name)
                    }
                }
            }
        }

        func getAvailableSections() -> [String] {
            let all = DEFAULT_LIBRARY_SECTIONS + priviledgedRunners.map(\.id)
            return all
                .filter { !sections.contains($0) }
        }
    }
}

// MARK: - Load Page Links

extension LibraryView {
    func loadPageLinks() async {
        triggeredLoad = true
        let actor = await RealmActor.shared()
        runners = await actor.getLibraryPageProviders()
        // Get Links
        let runnerIDs = runners.map(\.id)
        // Remove All
        withAnimation {
            pageLinks.removeAll()
        }
        // Load all links, log errors
        await withTaskGroup(of: Void.self) { group in
            for id in runnerIDs {
                group.addTask {
                    do {
                        let runner = try await DSK.shared.getDSKRunner(id)
                        guard runner.intents.libraryPageLinkProvider else { return }
                        let links = try await runner.getLibraryPageLinks()
                        guard !links.isEmpty else { return }
                        Task { @MainActor in
                            withAnimation {
                                pageLinks.updateValue(links, forKey: runner.id)
                            }
                        }
                    } catch {
                        Logger.shared.error(error, id)
                    }
                }
            }
        }
    }
}

extension LibraryView {
    struct DownloadSection: View {
        var body: some View {
            Section {
                NavigationLink {
                    SourceDownloadView()
                } label: {
                    Label("Downloaded Titles", systemImage: "externaldrive.badge.checkmark")
                }

                NavigationLink {
                    SourceDownloadQueueView()
                } label: {
                    Label("Source Queue", systemImage: "list.bullet.below.rectangle")
                }

                NavigationLink {
                    DirectoryViewer.DownloadQueueSheet()
                } label: {
                    Label("File Queue", systemImage: "list.bullet.indent")
                }
            } header: {
                Text("Downloads")
            }
            .headerProminence(.increased)
        }
    }
}
