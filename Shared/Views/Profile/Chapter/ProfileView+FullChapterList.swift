//
//  ProfileView+ChapterView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-18.
//

import RealmSwift
import SwiftUI

public extension Sequence {
    func sorted<Value: Comparable>(
        by keyPath: KeyPath<Self.Element, Value>, descending: Bool = true
    ) -> [Self.Element] {
        if descending {
            return sorted(by: { $0[keyPath: keyPath] > $1[keyPath: keyPath] })
        } else {
            return sorted(by: { $0[keyPath: keyPath] < $1[keyPath: keyPath] })
        }
    }
}

enum ChapterSortOption: Int, CaseIterable, Identifiable {
    case number, date, source

    var id: Int {
        hashValue
    }

    var description: String {
        switch self {
        case .number:
            return "Chapter Number"
        case .date:
            return "Chapter Date"
        case .source:
            return "Source Provided Index"
        }
    }
}

struct ChapterList: View {
    @EnvironmentObject var model: ProfileView.ViewModel
    @State var selection: String?
    @State var selections = Set<StoredChapter>()
    @State var presentOptions = false
    @ObservedResults(ICDMDownloadObject.self) var downloads
    @ObservedResults(ChapterMarker.self, where: { $0.chapter != nil }) var markers
    @AppStorage(STTKeys.ChapterListSortKey, store: .standard) var sortKey = ChapterSortOption.number
    @AppStorage(STTKeys.ChapterListDescending, store: .standard) var sortDesc = true
    @AppStorage(STTKeys.ChapterListShowOnlyDownloaded, store: .standard) var showOnlyDownloads = false
    @Environment(\.editMode) var editMode
    @AppStorage(STTKeys.FilteredProviders) private var filteredProviders: [String] = []
    @AppStorage(STTKeys.FilteredLanguages) private var filteredLanguages: [String] = []
    
    @ObservedResults(StoredChapter.self) private var storedChapters
    var body: some View {
        Group {
            if let chapters = model.chapters.value {
                let ordered = filteredChapters(chapters)
                ChaptersView(ordered)
                    .fullScreenCover(item: $selection, onDismiss: handleReconnection) { chapterId in
                        let chapter = chapters.first(where: { $0.chapterId == chapterId })!
                        ReaderGateWay(readingMode: model.content.recommendedReadingMode ?? .PAGED_COMIC, chapterList: ordered, openTo: chapter)
                    }
            } else {
                Text("No Chapters Found")
            }
        }
        .sheet(isPresented: $presentOptions, content: {
            FCS_Options()
        })
        .onChange(of: editMode?.wrappedValue, perform: { _ in
            selections.removeAll()
        })
        .animation(.default, value: selections)
        .navigationTitle("Chapters")
        .modifier(ConditionalToolBarModifier(showBB: Binding.constant(editMode?.wrappedValue == .active)))
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if editMode?.wrappedValue == .active {
                    Menu("Select") {
                        Button("Select All") { selectAll() }
                        Button("Deselect All") { deselectAll() }
                        Divider()
                        Button("Fill Range") { fillRange() }
                        Button("Invert Selection") { invertSelection() }
                        Divider()
                        Button("Select All Below") { selectBelow() }
                        Button("Select All Above") { selectAbove() }
                    }
                    Spacer()
                    Menu("Mark") {
                        Button("Read") { markAsRead() }
                        Button("Unread") { markAsUnread() }
                    }
                    Spacer()
                    Menu("Options") {
                        if let readingMode = model.content.recommendedReadingMode, ![ReadingMode.NOVEL, .WEB].contains(readingMode) {
                            Button("Download Chapter(s)") { addToDownloadQueue() }
                            Button("Delete / Cancel Download(s)", role: .destructive) { removeDownload() }
                        }

                        Button("Reset Chapter Data", role: .destructive) { clearChapterData() }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                EditButton()

                Menu {
                    Picker("Sort By", selection: $sortKey) {
                        ForEach(ChapterSortOption.allCases) {
                            Text($0.description)
                                .tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    Button {
                        sortDesc.toggle()
                    } label: {
                        Label("Order", systemImage: sortDesc ? "chevron.down" : "chevron.up")
                    }
                    Divider()
                    Button { showOnlyDownloads.toggle() } label: {
                        HStack {
                            Text("Downloaded Only")
                            Spacer()
                            if showOnlyDownloads {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Divider()
                    Button { presentOptions.toggle() } label: {
                        Label("Options", systemImage: "gear")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    func handleReconnection() {
        model.getMarkers()
    }

    func ChaptersView(_ chapters: [StoredChapter]) -> some View {
        List(chapters, id: \.self, selection: $selections) { chapter in
            let completed = isChapterCompleted(chapter)
            let newChapter = isChapterNew(chapter)
            let progress = chapterProgress(chapter)
            let download = getDownload(chapter)
            Button {
                if editMode?.wrappedValue != .active {
                    selection = chapter.chapterId
                }
            } label: {
                ChapterListTile(chapter: chapter,
                                isCompleted: completed,
                                isNewChapter: newChapter,
                                progress: progress,
                                download: download)
            }
            .buttonStyle(.plain)

            .background(
                Color.clear
                    .contextMenu {
                        Button {
                            DataManager.shared.bulkMarkChapter(chapters: [chapter], completed: !completed)
                        } label: {
                            Label(completed ? "Mark as Unread" : "Mark as Read", systemImage: completed ? "eye.slash.circle" : "eye.circle")
                        }
                        DownloadView(download, chapter)
                        ProviderView(chapter)
                    }
                    .id(chapter._id + completed.description + (download?.status.rawValue.description ?? "none"))
            )
        }
    }
}

extension ChapterList {
    func filteredChapters(_ chapters: [StoredChapter]) -> [StoredChapter] {
        // Filter Language, Providers, Downloads
        let base = chapters
            .filter(filterDownloads(_:))
            .filter(filterProviders(_:))
            .filter(filterLanguages(_:))
        
        // Sort
        switch sortKey {
        case .number:
            var sortedV = base.sorted { lhs, rhs in
                if lhs.volume == rhs.volume {
                    return lhs.number < rhs.number
                }
                if let lhv = lhs.volume, let rhv = rhs.volume {
                    return lhv < rhv
                } else {
                    return !(rhs.volume == nil && lhs.volume == nil) // In This case nil volumes are higher up the order
                }
            }

            if sortDesc { sortedV = sortedV.reversed() }
            return sortedV
        case .date:
            return base
                .sorted(by: \.date, descending: sortDesc)
        case .source:
            return base
                .sorted(by: \.index, descending: !sortDesc) // Reverese Source Index
        }
    }
    
    func filterDownloads(_ chapter: StoredChapter) -> Bool {
        if !showOnlyDownloads { return true }
        return downloads.contains(where: { $0._id == chapter._id })
    }
    
    func filterProviders(_ chapter: StoredChapter) -> Bool {
        if filteredProviders.isEmpty { return true }
        return chapter.providers.contains(where: { !filteredProviders.contains($0.id) })
    }
    
    func filterLanguages(_ chapter: StoredChapter) -> Bool {
        guard let lang = chapter.language else { return false }
        return !filteredLanguages.contains(lang)
        
    }
}

extension ChapterList {
    @ViewBuilder
    func DownloadView(_ download: ICDMDownloadObject?, _ chapter: StoredChapter) -> some View {
        if let download = download {
            switch download.status {
            case .cancelled:
                EmptyView()
            case .idle, .queued:
                Button(role: .destructive) {
                    ICDM.shared.cancel(ids: [chapter._id])
                } label: {
                    Label("Cancel Download", systemImage: "x.circle")
                }
            case .completed:
                Button(role: .destructive) {
                    ICDM.shared.cancel(ids: [chapter._id])
                } label: {
                    Label("Delete Download", systemImage: "trash.circle")
                }
            case .active:
                Group {
                    Button(role: .destructive) {
                        ICDM.shared.cancel(ids: [chapter._id])
                    } label: {
                        Label("Cancel Download", systemImage: "x.circle")
                    }
                    Button {
                        ICDM.shared.pause(ids: [chapter._id])
                    } label: {
                        Label("Pause Download", systemImage: "pause.circle")
                    }
                }
            case .paused:
                Button {
                    ICDM.shared.resume(ids: [chapter._id])
                } label: {
                    Label("Resume Download", systemImage: "play.circle")
                }
            case .failing:
                Button {
                    ICDM.shared.resume(ids: [chapter._id])
                } label: {
                    Label("Retry Download", systemImage: "arrow.counterclockwise.circle")
                }
                Button(role: .destructive) {
                    ICDM.shared.cancel(ids: [chapter._id])
                } label: {
                    Label("Cancel Download", systemImage: "x.circle")
                }
            }
        } else {
            Button {
                ICDM.shared.add(chapters: [chapter])
                let c = model.storedContent
                if !DataManager.shared.isInLibrary(content: c) {
                    DataManager.shared.toggleLibraryState(for: c)
                }
            } label: {
                Label("Download Chapter", systemImage: "tray.and.arrow.down")
            }
        }
    }

    @ViewBuilder
    func ProviderView(_ chapter: StoredChapter) -> some View {
        if !chapter.providers.isEmpty {
            Menu("Providers") {
                ForEach(chapter.providers) { provider in
                    Menu(provider.name) {
                        if provider.links.isEmpty {
                            Text("No Links")
                        } else {
                            ForEach(provider.links, id: \.url) { link in
                                Link(destination: URL(string: link.url) ?? STTHost.notFound) {
                                    Text(link.type.description)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

extension ChapterList {
    func isChapterCompleted(_ chapter: StoredChapter) -> Bool {
        let base = markers
            .where { $0.chapter.sourceId == chapter.sourceId }
            .where { $0.chapter.contentId == chapter.contentId }
            .where { $0._id == chapter._id || ($0.chapter.number == chapter.number && $0.chapter.volume == chapter.volume) }

        let markedCompleted = base
            .where { $0.completed == true }
            .count >= 1

        let progressCompleted = base
            .where { $0.lastPageRead == $0.totalPageCount }
            .count >= 1
        return progressCompleted && markedCompleted
    }

    func isChapterNew(_ chapter: StoredChapter) -> Bool {
        guard let date = model.actionState.marker?.date else {
            return false
        }
        return chapter.date > date
    }

    func chapterProgress(_ chapter: StoredChapter) -> Double? {
        guard let id = model.actionState.chapter?._id, id == chapter._id else {
            return nil
        }
        return model.actionState.marker?.progress
    }

    func getDownload(_ chapter: StoredChapter) -> ICDMDownloadObject? {
        downloads
            .where { $0._id == chapter._id }
            .first
    }
}

extension ChapterList {
    func selectAbove() {
        if selections.isEmpty { return }

        let chapters = filteredChapters(model.chapters.value ?? [])
        let target = selections.first

        guard let target, let idx = chapters.firstIndex(of: target) else { return }

        let sub = chapters[0 ... idx]
        selections.formUnion(sub)
    }

    func selectBelow() {
        if selections.isEmpty { return }

        let chapters = filteredChapters(model.chapters.value ?? [])
        let target = selections.first

        guard let target, let idx = chapters.firstIndex(of: target) else { return }

        let sub = chapters[idx...]
        selections.formUnion(sub)
    }

    func selectAll() {
        let cs = filteredChapters(model.chapters.value ?? [])
        selections = Set(cs)
    }

    func deselectAll() {
        selections.removeAll()
    }

    func fillRange() {
        if selections.isEmpty { return }

        let cs = filteredChapters(model.chapters.value ?? [])

        var indexes = [Int]()

        for c in selections {
            if let index = cs.firstIndex(of: c) {
                indexes.append(index)
            }
        }
        indexes.sort()
        //
        let start = indexes.first!
        let end = indexes.last!
        //
        selections = Set(cs[start ... end])
    }

    func invertSelection() {
        let cs = filteredChapters(model.chapters.value ?? [])
        selections = Set(cs.filter { !selections.contains($0) })
    }

    func markAsRead() {
        DataManager.shared.bulkMarkChapter(chapters: Array(selections))
        deselectAll()
    }

    func markAsUnread() {
        DataManager.shared.bulkMarkChapter(chapters: Array(selections), completed: false)
        deselectAll()

        let c = model.storedContent
        if !DataManager.shared.isInLibrary(content: c) {
            DataManager.shared.toggleLibraryState(for: c)
        }
    }

    func addToDownloadQueue() {
        ICDM.shared.add(chapters: Array(selections))
        deselectAll()
    }

    func removeDownload() {
        ICDM.shared.cancel(ids: Array(selections).map(\._id))
        deselectAll()
    }

    func clearChapterData() {
        selections.forEach {
            DataManager.shared.resetChapterData(forId: $0._id)
        }
        deselectAll()
    }
}
