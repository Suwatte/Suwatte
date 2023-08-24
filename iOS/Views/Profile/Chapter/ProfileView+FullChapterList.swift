//
//  ProfileView+FullChapterList.swift
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
    @State var selections = Set<ThreadSafeChapter>()
    @State var presentOptions = false
    @AppStorage(STTKeys.ChapterListSortKey, store: .standard) var sortKey = ChapterSortOption.number
    @AppStorage(STTKeys.ChapterListDescending, store: .standard) var sortDesc = true
    @AppStorage(STTKeys.ChapterListShowOnlyDownloaded, store: .standard) var showOnlyDownloads = false
    @Environment(\.editMode) var editMode
    @AppStorage(STTKeys.FilteredProviders) private var filteredProviders: [String] = []
    @AppStorage(STTKeys.FilteredLanguages) private var filteredLanguages: [String] = []
    @State var visibleChapters: [ThreadSafeChapter] = []
    var body: some View {
        Group {
            ChaptersView(visibleChapters)
                .fullScreenCover(item: $selection, onDismiss: handleReconnection) { chapterId in
//                    let chapter = visibleChapters.first(where: { $0.chapterId == chapterId })!
//                    ReaderGateWay(readingMode: model.content.recommendedReadingMode ?? .defaultPanelMode,
//                                  chapterList: visibleChapters,
//                                  openTo: chapter)
//                        .onAppear {
//                            model.removeNotifier()
//                        }
                    Text("Broken")
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

                Menu {
                    Picker("Sort By", selection: $sortKey) {
                        ForEach(filterCases) {
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
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
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

    @ViewBuilder
    var BottomBar: some View {
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
            Button("Download Chapter(s)") { addToDownloadQueue() }
            Button("Delete / Cancel Download(s)", role: .destructive) { removeDownload() }
            Divider()
            Button("Reset Chapter Data", role: .destructive) { clearChapterData() }
        }
    }

    func ChaptersView(_ chapters: [ThreadSafeChapter]) -> some View {
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
                ChapterListTile(chapter: chapter.toStored(),
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
                        Button {
                            let id = model.STTIDPair
                            Task {
                                let actor = await RealmActor()
                                await actor.bulkMarkChapters(for: id,
                                                             chapters: [chapter],
                                                             markAsRead: !completed)
                            }
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
                        DownloadView(download, chapter.id)
                        ProviderView(chapter)
                    }
                    .id(genId(chapter.id, completed, download))
            )
        }
    }
}

extension ChapterList {
    func doFilter() {
        let chapters = model.chapters
        DispatchQueue.global(qos: .background).async {
            filterChapters(chapters: chapters)
        }
    }

    func filterChapters(chapters: [ThreadSafeChapter]) {
        // Core filters
        var base = chapters
            .filter(filterDownloads(_:))
            .filter(filterProviders(_:))
            .filter(filterLanguages(_:))

        switch sortKey {
        case .date:
            base = base
                .sorted(by: \.date, descending: sortDesc)
        case .source:
            base = base
                .sorted(by: \.index, descending: !sortDesc) // Reverese Source Index
        case .number:
                base = base
                    .sorted(by: \.chapterOrderKey, descending: !sortDesc) // Reverese Source Index
        }

        Task { @MainActor in
            withAnimation {
                visibleChapters = base
            }
        }
    }

    func filterDownloads(_ chapter: ThreadSafeChapter) -> Bool {
        if !showOnlyDownloads { return true }
        return model.downloads[chapter.id] != nil
    }

    func filterProviders(_ chapter: ThreadSafeChapter) -> Bool {
        if filteredProviders.isEmpty { return true }
        return (chapter.providers ?? []).contains(where: { !filteredProviders.contains($0.id) })
    }

    func filterLanguages(_ chapter: ThreadSafeChapter) -> Bool {
        guard let lang = chapter.language else { return true }
        return !filteredLanguages.contains(lang)
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
//        if let providers, !providers.isEmpty {
//            Menu("Providers") {
//                ForEach(providers, id: \.id) { provider in
//                    Menu(provider.name) {
//                        if provider.links.isEmpty {
//                            Text("No Links")
//                        } else {
//                            ForEach(provider.links, id: \.url) { link in
//                                Link(destination: URL(string: link.url) ?? STTHost.notFound) {
//                                    Text(link.type.description)
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//
//        }
        EmptyView()

    }
}

extension ChapterList {
    func isChapterCompleted(_ chapter: ThreadSafeChapter) -> Bool {
        model.readChapters.contains(chapter.chapterOrderKey)
    }

    func isChapterNew(_ chapter: ThreadSafeChapter) -> Bool {
        guard let date = model.actionState.marker?.date else {
            return false
        }
        return chapter.date > date
    }

    func chapterProgress(_ chapter: ThreadSafeChapter) -> Double? {
        guard let id = model.actionState.chapter?.id, id == chapter.id else {
            return nil
        }
        return model.actionState.marker?.progress
    }

    func getDownload(_ chapter: ThreadSafeChapter) -> DownloadStatus? {
        model.downloads[chapter.id]
    }
}

extension ChapterList {
    func mark(chapter: ThreadSafeChapter, read: Bool, above: Bool) {
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
        let id = model.STTIDPair
        let chapters = Array(selections)
        Task {
            let actor = await RealmActor()
            await actor.bulkMarkChapters(for: id, chapters: chapters)
        }
        deselectAll()
        didMark()
    }

    func markAsUnread() {
        let id = model.STTIDPair
        let chapters = Array(selections)
        Task {
            let actor = await RealmActor()
            await actor.bulkMarkChapters(for: id, chapters: chapters, markAsRead: false)
        }
        deselectAll()
    }

    func addToDownloadQueue() {
        let ids = Array(selections).map(\.id)
        Task {
            await SDM.shared.add(chapters: ids)
        }
        deselectAll()
    }

    func removeDownload() {
        let ids = Array(selections).map(\.id)
        Task {
            await SDM.shared.cancel(ids: ids)
        }
        deselectAll()
    }

    func clearChapterData() {
        let ids = selections.map(\.id)
        Task {
            let actor = await RealmActor()
            await actor.resetChapterData(for: ids)
        }
        deselectAll()
    }

    func didMark() { // This is called before the notification is delivered to for model `readChapters` property to update
        let identifier = model.identifier
        Task {
            let actor = await RealmActor()
            let maxRead = await actor
                .getContentMarker(for: identifier)?
                .readChapters
                .max()
            let progress = DSKCommon.TrackProgressUpdate(chapter: maxRead, volume: nil) // TODO: Probably Want to get the volume here
            await actor.updateTrackProgress(for: identifier, progress: progress)
        }
    }
}

extension ChapterList {
    struct DownloadContextView: View {
        let id: String
        let status: DownloadStatus
        var body: some View {
            Group {
                switch status {
                case .cancelled:
                    EmptyView()
                case .idle, .queued:
                    Button(role: .destructive) {
                        Task {
                            await SDM.shared.cancel(ids: [id])
                        }
                    } label: {
                        Label("Cancel Download", systemImage: "x.circle")
                    }
                case .completed:
                    Button(role: .destructive) {
                        Task {
                            await SDM.shared.cancel(ids: [id])
                        }
                    } label: {
                        Label("Delete Download", systemImage: "trash.circle")
                    }
                case .active:
                    Group {
                        Button(role: .destructive) {
                            Task {
                                await SDM.shared.cancel(ids: [id])
                            }

                        } label: {
                            Label("Cancel Download", systemImage: "x.circle")
                        }
                        Button {
                            Task {
                                await SDM.shared.pause(ids: [id])
                            }
                        } label: {
                            Label("Pause Download", systemImage: "pause.circle")
                        }
                    }
                case .paused:
                    Button {
                        Task {
                            await SDM.shared.resume(ids: [id])
                        }
                    } label: {
                        Label("Resume Download", systemImage: "play.circle")
                    }
                case .failing:
                    Button {
                        Task {
                            await SDM.shared.resume(ids: [id])
                        }
                    } label: {
                        Label("Retry Download", systemImage: "arrow.counterclockwise.circle")
                    }
                    Button(role: .destructive) {
                        Task {
                            await SDM.shared.cancel(ids: [id])
                        }
                    } label: {
                        Label("Cancel Download", systemImage: "x.circle")
                    }
                }
            }
        }
    }
}
