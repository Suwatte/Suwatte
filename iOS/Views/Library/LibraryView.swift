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
    @StateObject var pageProviderModel = PageLinkProviderModel(isForBrowsePage: false)
    @State var presentCollectionSheet = false
    @State var presentOrderSheet = false
    @State var openFirstCollection = false
    @State var hasOpenedFirst = false
    @AppStorage(STTKeys.OpenAllTitlesOnAppear) var openAllOnAppear = false
    @AppStorage(STTKeys.LibraryAuth) var requireAuth = false
    @State var hasLoadedPages = false
    @AppStorage(STTKeys.UseCompactLibraryView) var useCompactView = false

    var body: some View {
        List {
            BrowseView.PendingSetupView()
            ForEach(sections) { section in
                LibrarySectionBuilder(key: section)
            }
        }
        .environmentObject(pageProviderModel)
        .refreshable {
            pageProviderModel.reload()
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Library")
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        useCompactView.toggle()
                    } label: {
                        Label("Compact Mode", systemImage: "list.bullet.circle")
                    }

                    Divider()

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
            SmartNavigationView {
                LibrarySectionOrderSheet()
                    .environment(\.editMode, .constant(.active))
                    .navigationTitle("Library Sections")
                    .navigationBarTitleDisplayMode(.inline)
                    .closeButton()
            }

        })
        .hiddenNav(presenting: $openFirstCollection) {
            LibraryGrid(collection: nil, readingFlag: nil)
        }
        .hiddenNav(presenting: $useCompactView) {
            // HACK: Nasty hack due to the underlying Collection View performing weird layout shifts and therefore causing the Nav Bar to disappear
            CompactLibraryView()
                .navigationBarBackButtonHidden(true)
        }

        .task {
            if requireAuth && !LocalAuthManager.shared.isExpired {
                return
            }

            if openAllOnAppear && !hasOpenedFirst {
                withAnimation {
                    openFirstCollection = true
                    hasOpenedFirst = true
                }
            }
        }
        .sheet(isPresented: $presentCollectionSheet) {
            ManageCollectionsView()
        }
        .task {
            guard !hasLoadedPages else { return }
            await pageProviderModel.observe()
            hasLoadedPages = true
        }
        .onChange(of: sections) { _ in
            pageProviderModel.reload()
        }
        .onReceive(StateManager.shared.runnerListPublisher) { _ in
            pageProviderModel.reload()
        }
        .onReceive(StateManager.shared.libraryUpdateRunnerPageLinks) { _ in
            hasLoadedPages = false
        }
        .onDisappear {
            pageProviderModel.stopObserving()
        }
        .animation(.default, value: pageProviderModel.links)
        .animation(.default, value: pageProviderModel.runners)
        .animation(.default, value: pageProviderModel.pending)
        .fullScreenCover(item: $pageProviderModel.selectedRunnerRequiringSetup, onDismiss: pageProviderModel.reload, content: { runnerOBJ in
            SmartNavigationView {
                LoadableRunnerView(runnerID: runnerOBJ.id) { runner in
                    DSKLoadableForm(runner: runner, context: .setup(closeOnSuccess: true))
                }
                .navigationTitle("\(runnerOBJ.name) Setup")
                .closeButton()
            }
        })
        .fullScreenCover(item: $pageProviderModel.selectedRunnerRequiringAuth, onDismiss: pageProviderModel.reload, content: { runnerOBJ in
            SmartNavigationView {
                LoadableRunnerView(runnerID: runnerOBJ.id) { runner in
                    List {
                        DSKAuthView(model: .init(runner: runner))
                    }
                }
                .navigationTitle("Sign In to \(runnerOBJ.name)")
                .navigationBarTitleDisplayMode(.inline)
                .closeButton(title: "Done")
            }

        })
    }
}

// MARK: - Section Builder

extension LibraryView {
    struct LibrarySectionBuilder: View {
        let key: String
        @EnvironmentObject var model: PageLinkProviderModel

        private var providers: [StoredRunnerObject] {
            model
                .runners
                .filter { $0.isLibraryPageLinkProvider }
        }

        var body: some View {
            Group {
                switch key {
                case "library.local":
                    LibrarySectionView()
                case "library.lists":
                    ListsSectionView()
                case "library.collections":
                    CollectionsSectionView()
                case "library.flags":
                    FlagsSectionView()
                case "library.downloads":
                    DownloadSection()
                default:
                    if let pageLinks = model.links[key], let runner = providers.first(where: { $0.id == key }) {
                        PageLinkSectionView(runner: runner, pageLinks: pageLinks)
                    } else {
                        EmptyView()
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
                        PageLinkView(link: pageLink.link, title: pageLink.title, runnerID: runner.id)
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
                        LibraryGrid(collection: nil, readingFlag: flag)
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
        @EnvironmentObject private var stateManager: StateManager

        private var collections: [LibraryCollection] {
            stateManager.collections
        }

        var body: some View {
            Section {
                NavigationLink {
                    LibraryGrid(collection: nil, readingFlag: nil)
                } label: {
                    Label("All Titles", systemImage: "folder")
                }

                ForEach(collections) { collection in
                    NavigationLink {
                        LibraryGrid(collection: collection, readingFlag: nil)
                    } label: {
                        Label(collection.name, systemImage: "archivebox")
                    }
                }
            } header: {
                Text("Collections")
            }
            .headerProminence(.increased)
            .animation(.default, value: stateManager.collections)
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
