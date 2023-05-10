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
    @AppStorage(STTKeys.ChapterListSortKey, store: .standard) var sortKey = ChapterSortOption.number
    @AppStorage(STTKeys.ChapterListDescending, store: .standard) var sortDesc = true
    @AppStorage(STTKeys.ChapterListShowOnlyDownloaded, store: .standard) var showOnlyDownloads = false
    @Environment(\.editMode) var editMode
    @AppStorage(STTKeys.FilteredProviders) private var filteredProviders: [String] = []
    @AppStorage(STTKeys.FilteredLanguages) private var filteredLanguages: [String] = []
    @State var visibleChapters: [StoredChapter] = []
    var body: some View {
        Group {
            ChaptersView(visibleChapters)
                .fullScreenCover(item: $selection, onDismiss: handleReconnection) { chapterId in
                    let chapter = visibleChapters.first(where: { $0.chapterId == chapterId })!
                    ReaderGateWay(readingMode: model.content.recommendedReadingMode ?? .PAGED_COMIC, chapterList: visibleChapters, openTo: chapter)
                        .onAppear {
                            model.removeNotifier()
                        }
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
        .onChange(of: filteredProviders) { _ in
            doFilter()
        }
        .onChange(of: filteredLanguages) { _ in
            doFilter()
        }
    }

    func handleReconnection() {
        DispatchQueue.main.async {
            model.getMarkers()
            model.setupObservers()
        }
    }
    
    func genId(_ id: String, _ completed: Bool, _ download: ICDMDownloadObject?) -> String {
        
        var id = id
        
        id += completed.description
        
        if let download , !download.isInvalidated {
            
            id += download.status.rawValue.description
        } else {
            id += "none"
        }
        
        return id
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
                            didMark()
                        } label: {
                            Label(completed ? "Mark as Unread" : "Mark as Read", systemImage: completed ? "eye.slash.circle" : "eye.circle")
                        }
                        Menu("Mark Below") {
                            Button { mark(chapter: chapter, read: true, above: false) } label: {
                                Label("As Read", systemImage: "eye.circle")
                            }

                            Button { mark(chapter: chapter, read: false, above: false) } label: {
                                Label("As Unread", systemImage: "eye.slash.circle")
                            }
                        }
                        DownloadView(download, chapter)
                        ProviderView(chapter)
                    }
                    .id(genId(chapter._id, completed, download))
            )
        }
    }
}

extension ChapterList {
    func doFilter() {
        guard let chapters = model.chapters.value else { return }
        let ids = chapters.map(\._id)
        DispatchQueue.global(qos: .background).async {
            filterChapters(ids: ids)
        }
    }

    func filterChapters(ids: [String]) {
        let realm = try! Realm()
        
        let chapters = realm.objects(StoredChapter.self).where({ $0._id.in(ids) }).toArray()
        
        // Filter Language, Providers, Downloads
        var base = chapters
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
            base = sortedV
        case .date:
            base = base
                .sorted(by: \.date, descending: sortDesc)
        case .source:
            base = base
                .sorted(by: \.index, descending: !sortDesc) // Reverese Source Index
        }
        
        let ids = base.map(\._id)
        Task { @MainActor in
            let realm = try! Realm()
            withAnimation {
                visibleChapters = realm.objects(StoredChapter.self).where({ $0._id.in(ids) }).toArray()
            }
        }
    }

    func filterDownloads(_ chapter: StoredChapter) -> Bool {
        if !showOnlyDownloads { return true }
        return DataManager.shared.hasDownload(id: chapter._id)
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
        if let download = download, !download.isInvalidated {
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
                ICDM.shared.add(chapters: [chapter._id])
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
        model.readChapters.contains(chapter.number)
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
        model.downloads[chapter._id]
    }
}

extension ChapterList {
    func mark(chapter: StoredChapter, read: Bool, above: Bool) {
        selections.removeAll()
        selections.insert(chapter)
        if above {
            selectAbove()
        } else {
            selectBelow()
        }
        selections.remove(chapter)
        if read {
            markAsRead()
        } else {
            markAsUnread()
        }
    }

    func selectAbove() {
        if selections.isEmpty { return }

        let chapters = visibleChapters
        let target = selections.first

        guard let target, let idx = chapters.firstIndex(of: target) else { return }

        let sub = chapters[0 ... idx]
        selections.formUnion(sub)
    }

    func selectBelow() {
        if selections.isEmpty { return }

        let chapters = visibleChapters
        let target = selections.first

        guard let target, let idx = chapters.firstIndex(of: target) else { return }

        let sub = chapters[idx...]
        selections.formUnion(sub)
    }

    func selectAll() {
        let cs = visibleChapters
        selections = Set(cs)
    }

    func deselectAll() {
        selections.removeAll()
    }

    func fillRange() {
        if selections.isEmpty { return }

        let cs = visibleChapters

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
        let cs = visibleChapters
        selections = Set(cs.filter { !selections.contains($0) })
    }

    func markAsRead() {
        DataManager.shared.bulkMarkChapter(chapters: Array(selections))
        deselectAll()
        didMark()
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
        ICDM.shared.add(chapters: Array(selections).map(\._id))
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

    func didMark() {
        Task.detached {
            try? await model.handleAnilistSync()
        }
    }
}
