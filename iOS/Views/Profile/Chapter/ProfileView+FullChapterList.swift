//
//  ProfileView+FullChapterList.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-18.
//

import RealmSwift
import SwiftUI

struct ChapterList: View {
    @ObservedObject var model: ProfileView.ViewModel
    @State var selection: ThreadSafeChapter?
    @State var selections = Set<ThreadSafeChapter>()
    @State var presentOptions = false
    
    @AppStorage(STTKeys.ChapterListSortKey) var sortKey = ChapterSortOption.number
    @AppStorage(STTKeys.ChapterListDescending) var sortDesc = true
    @AppStorage(STTKeys.ChapterListShowOnlyDownloaded) var showOnlyDownloads = false
    @AppStorage(STTKeys.GroupByVolume) var groupByVolume = false
    
    @Environment(\.editMode) var editMode
    var body: some View {
        
        Group {
            if groupByVolume {
                GroupChapterList()
            } else {
                ChaptersView(model.chapterListChapters)
            }
        }

        .sheet(isPresented: $presentOptions, content: {
            FCS_Options()
        })
        .onChange(of: editMode?.wrappedValue, perform: { _ in
            selections.removeAll()
        })
        .animation(.default, value: selections)
        .animation(.default, value: model.actionState)
        .navigationTitle("Chapters")
        .modifier(ConditionalToolBarModifier(showBB: Binding.constant(editMode?.wrappedValue == .active)))
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if editMode?.wrappedValue == .active {
                    BottomBar
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                EditButton()
                MenuButton()
            }
        }
        .onAppear {
            doFilter()
        }
        .onChange(of: sortKey) { _ in
            doFilter()
        }
        .onChange(of: sortDesc) { _ in
            doFilter()
        }
        .onChange(of: showOnlyDownloads) { _ in
            doFilter()
        }
        .fullScreenCover(item: $selection, onDismiss: handleReconnection) { chapter in
            let readingMode = model.readingMode
            ReaderGateWay(title: model.content.title,
                          readingMode: readingMode,
                          chapterList: model.chapterListChapters,
                          openTo: chapter)
            .task {
                model.removeNotifier()
            }
        }
    }

    var filterCases: [ChapterSortOption] {
        let removeDate = !model.source.ablityNotDisabled(\.disableChapterDates)

        if removeDate {
            return ChapterSortOption.allCases.filter { $0 != .date }
        }
        return ChapterSortOption.allCases
    }

    func handleReconnection() {
        Task {
            await model.setupObservers()
        }
    }
}

extension ChapterList {
    @ViewBuilder
    func BuildTile(_ chapter: ThreadSafeChapter) -> some View {
        let completed = isChapterCompleted(chapter)
        let newChapter = isChapterNew(chapter)
        let progress = chapterProgress(chapter)
        let download = getDownload(chapter)
        
        Button {
            if editMode?.wrappedValue != .active {
                selection = chapter
            }
        } label: {
            ChapterListTile(chapter: chapter,
                            isCompleted: completed,
                            isNewChapter: newChapter,
                            progress: progress,
                            download: download,
                            isLinked: chapter.sourceId != model.source.id,
                            showLanguageFlag: model.source.ablityNotDisabled(\.disableLanguageFlags),
                            showDate: model.source.ablityNotDisabled(\.disableChapterDates))
        }
        .buttonStyle(.plain)

        .background(
            Color.clear
                .contextMenu {
                    MenuView(for: chapter, completed: completed, status: download)
                }
                .id(genId(chapter.id, completed, download))
        )
    }
    func genId(_ id: String, _ completed: Bool, _ status: DownloadStatus?) -> String {
        var id = id

        id += completed.description

        if let status {
            id += status.rawValue.description
        } else {
            id += "none"
        }

        return id
    }

    func ChaptersView(_ chapters: [ThreadSafeChapter]) -> some View {
        List(chapters, id: \.self, selection: $selections) { chapter in
           BuildTile(chapter)
        }
    }
}


extension ChapterList {
    @ViewBuilder
    func GroupChapterList() -> some View {
        let groups = GroupedByVolume()
        let keys = Array(groups.keys).sorted(by: \.self, descending: true)
        List {
            ForEach(keys, id: \.self) { key in
                let data = groups[key]!
                Section {
                    ForEach(data) { chapter in
                        BuildTile(chapter)
                    }
                } header: {
                    if key == 999 {
                        Text("No Volume")
                    } else {
                        Text("Volume \(key.clean)")
                    }
                }
                .headerProminence(.increased)
            }
        }
        
    }
    
    func GroupedByVolume() -> [Double: [ThreadSafeChapter]] {
        Dictionary(grouping: model.chapterListChapters, by: \.inferredVolume)
    }
}

extension ChapterList {
    @ViewBuilder
    func DownloadView(_ status: DownloadStatus?, _ id: String) -> some View {
        Group {
            if let status {
                DownloadContextView(id: id, status: status)
            } else {
                Button {
                    Task {
                        await SDM.shared.add(chapters: [id])
                    }
                } label: {
                    Label("Download Chapter", systemImage: "tray.and.arrow.down")
                }
            }
        }
    }

    @ViewBuilder
    func ProviderView(_ chapter: ThreadSafeChapter) -> some View {
        let providers = chapter.providers
        if let providers, !providers.isEmpty {
            Menu("Providers") {
                ForEach(providers, id: \.id) { provider in
                    if let links = provider.links, !links.isEmpty {
                        ForEach(links, id: \.url) { link in
                            Link(destination: URL(string: link.url) ?? STTHost.notFound) {
                                Text(link.type.description)
                            }
                        }
                    } else {
                        Text("No Links")
                    }
                }
            }
        }
    }
}
