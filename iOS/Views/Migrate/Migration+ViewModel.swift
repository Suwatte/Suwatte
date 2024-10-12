//
//  Migration+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-27.
//

import Foundation
import RealmSwift
import SwiftUI

final class MigrationController: ObservableObject {
    @Published var contents: [TaggedHighlight]
    @Published var libraryStrat = LibraryMigrationStrategy.replace
    @Published var notFoundStrat = NotFoundMigrationStrategy.skip
    @Published var lessChapterSrat = LowerChapterMigrationStrategy.skip
    @Published var operationState = MigrationOperationState.idle

    @Published var presentConfirmationAlert = false
    @Published var selectedToSearch: TaggedHighlight? = nil

    @Published var operations: [String: MigrationItemState] = [:]
    @Published var preferredDestinations: [AnyContentSource] = []
    @Published var availableDestinations: [AnyContentSource] = []
    @Published var sources: [String: AnyContentSource] = [:]

    @Published var hasLoadedSources: Bool = false
    @Published var hasSortedContent: Bool = false
    var operationsTask: Task<Void, Never>?

    init(contents: [TaggedHighlight]) {
        self.contents = contents
    }
}

// MARK: Initial Loading

extension MigrationController {
    func loadSources() async {
        let sources = await DSK
            .shared
            .getActiveSources()
            .filter { $0.ablityNotDisabled(\.disableMigrationDestination) }
        var nonIsolatedDict: [String: AnyContentSource] = [:]
        for source in sources {
            nonIsolatedDict[source.id] = source
        }
        let prepped = nonIsolatedDict
        await MainActor.run { [weak self] in
            self?.sources = prepped
            self?.availableDestinations = sources
            self?.hasLoadedSources = true
        }
    }

    func sortContents() async {
        let prepped = contents
            .sorted(by: \.title, descending: false)

        await MainActor.run { [weak self] in
            self?.contents = prepped
            self?.hasSortedContent = true
        }
    }
}

extension MigrationController {
    func cancelOperations() {
        operationsTask?.cancel()
        operationsTask = nil
    }

    func removeItem(id: String) {
        withAnimation {
            contents.removeAll(where: { $0.id == id })
            operations.removeValue(forKey: id)
        }
    }

    func filterNonMatches() {
        let cases = contents.filter { content in
            let data = operations[content.id]
            guard let data else { return true }
            switch data {
            case .found, .lowerFind: return false
            default: return true
            }
        }.map(\.id)

        withAnimation {
            contents.removeAll(where: { cases.contains($0.id) })
            cases.forEach {
                operations.removeValue(forKey: $0)
            }
        }
    }
}

// MARK: Searching

extension MigrationController {
    func search() async {
        await MainActor.run(body: {
            operationState = .searching
        })

        let actor = await RealmActor.shared()
        for content in contents {
            let lastChapter = await actor.getLatestStoredChapter(content.sourceID,
                                                                 content.contentID)?.number
            let sources = preferredDestinations
            if Task.isCancelled {
                return
            }
            // Get Content & Chapters
            let result = await handleSourcesSearch(id: content.id, query: content.title, chapter: lastChapter, sources: sources)

            await MainActor.run {
                withAnimation {
                    operations[result.id] = result.state
                }
            }
        }

        await MainActor.run(body: {
            operationState = .searchComplete
        })
    }

    private typealias ReturnValue = (entry: TaggedHighlight, number: Double, chapterCount: Int)
    private func handleSourcesSearch(id: String, query: String, chapter: Double?, sources: [AnyContentSource]) async -> (id: String, state: MigrationItemState) {
        await withTaskGroup(of: ReturnValue?.self, body: { group in

            for source in sources {
                guard !Task.isCancelled else {
                    return (id, .idle)
                }

                group.addTask { [weak self] in
                    await self?.searchSource(query: query, source: source)
                }
            }

            let singleSourceMigration = sources.count == 1

            var max: ReturnValue?
            for await value in group {
                if let value {

                    // Skip migrating to the same item
                    if !singleSourceMigration && id == value.entry.id {
                        continue
                    }

                    // Chapter matches
                    let currentChapterNumber = max?.number ?? 0
                    let matches = value.number >= currentChapterNumber

                    if matches {
                        if let sourceId = max?.entry.sourceID {
                            let index = sources.firstIndex(where: { $0.id == value.entry.sourceID }) ?? Int.max
                            let currentSourceIndex = sources.firstIndex(where: { $0.id == sourceId }) ?? Int.max

                            if index < currentSourceIndex {
                                max = value
                            }
                        } else {
                            if currentChapterNumber <= value.number {
                                max = value
                            }
                        }
                    }
                }
            }

            if let max {
                if max.number >= (chapter ?? 0) {
                    return (id, .found(max.entry, max.chapterCount))
                } else {
                    return (id, .lowerFind(max.entry, chapter ?? 0, max.number, max.chapterCount))
                }
            } else {
                return (id, .noMatches)
            }
        })
    }

    private func searchSource(query: String, source: AnyContentSource) async -> ReturnValue? {
        let data: DSKCommon.PagedResult? = try? await source.getDirectory(request: .init(query: query, page: 1))
        let result = data?.results.first

        guard let result else { return nil }
        let contentId = result.id
        let content = try? await source.getContent(id: contentId)
        guard let content else { return nil }

        var chapters = content.chapters

        if chapters == nil {
            chapters = await getChapters(for: source, id: contentId)
        }

        let target = chapters?.first

        guard let target else { return nil }

        return (TaggedHighlight(from: result, with: source.id), target.number, chapters?.count ?? 0)
    }

    func getChapters(for sourceId: String, id: String) async -> [DSKCommon.Chapter]? {
        guard let source = sources[sourceId] else {
            return nil
        }

        return await getChapters(for: source, id: id)
    }

    private func getChapters(for source: AnyContentSource, id: String) async -> [DSKCommon.Chapter] {
        (try? await source.getContentChapters(contentId: id)) ?? []
    }

    func getStoredChapterCount(for content: TaggedHighlight) async -> Int {
        let actor = await RealmActor.shared()
        return await actor.getStoredChapterCount(content.sourceID, content.contentID)
    }
}

extension MigrationController {
    func migrate() async -> Bool {
        defer {
            Task { @MainActor in
                ToastManager.shared.loading = false
            }
        }

        await MainActor.run {
            ToastManager.shared.loading = true
            ToastManager.shared.info("Migration In Progress\nYour Data is being backed up.")
        }

        do {
            try await BackupManager.shared.save(name: "PreMigration")
        } catch {
            Task { @MainActor in
                ToastManager.shared.error(error)
            }
            return false
        }

        let realm = try! await Realm(actor: BGActor.shared)

        func get(_ id: String) -> LibraryEntry? {
            realm
                .objects(LibraryEntry.self)
                .where { $0.id == id }
                .first
        }

        func link(_ entry: LibraryEntry, with highlight: TaggedHighlight) {
            let one = entry.id
            let two = highlight.id
            
            if one == two {
                return
            }
            
            let isAlreadyLinked = !realm
                .objects(ContentLink.self)
                .where { $0.entry.id == one && $0.content.id == two && $0.isDeleted == false }
                .isEmpty

            if isAlreadyLinked {
                return
            }

            let object = ContentLink()
            object.entry = entry
            object.content = findOrCreate(highlight)
            realm.add(object, update: .modified)
        }

        func remove(_ entry: LibraryEntry) {
            entry.isDeleted = true
        }

        func replace(_ entry: LibraryEntry, with highlight: TaggedHighlight) {
            let object = LibraryEntry()
            object.content = findOrCreate(highlight)
            object.collections = entry.collections
            object.flag = entry.flag
            object.dateAdded = entry.dateAdded
            
            let progressMarkers = realm
                .objects(ProgressMarker.self)
                .where { $0.chapter.content.sourceId == entry.content!.sourceId 
                    && $0.chapter.content.contentId == entry.content!.contentId
                    && !$0.isDeleted }
                .freeze()
                .toArray()
            
            let highlightChapters = realm
                .objects(StoredChapter.self)
                .where { $0.contentId == highlight.contentID }
                .where { $0.sourceId == highlight.sourceID }
                .freeze()
                .toArray()
            
            // Update Read Chapters
            let readChaptersByOrderKey = progressMarkers.filter { $0.isCompleted }.map { $0.chapter!.chapterOrderKey }
            let readChaptersByNumber: [Double] = readChaptersByOrderKey.compactMap { chapterOrderKey in
                let chapterNumber = ThreadSafeChapter.orderKey(volume: nil, number: ThreadSafeChapter.vnPair(from: chapterOrderKey).1)
                guard let chapterRef = highlightChapters.first(where: { $0.chapterOrderKey == chapterNumber }) else {
                    return nil
                }

                let reference: ChapterReference? = chapterRef.generateReference()
                reference?.content = realm.objects(StoredContent.self).first { $0.id == chapterRef.contentIdentifier.id && !$0.isDeleted }

                guard let reference, reference.isValid else {
                    Logger.shared.error("Invalid Chapter Reference")
                    return nil
                }

                realm.add(reference, update: .modified)

                let marker = ProgressMarker()
                marker.id = chapterRef.id
                marker.chapter = reference
                marker.setCompleted(hideInHistory: true)
                marker.isDeleted = false
                realm.add(marker, update: .modified)
                return chapterNumber
            }

            /// Get All Unread
            let unreadChapters = highlightChapters
                .filter { !readChaptersByNumber.contains($0.chapterOrderKey) }
                .distinct(by: \.number)
                .map { $0.toThreadSafe() }

            /// Apply Filter
            let count = STTHelpers.filterChapters(unreadChapters, with: ContentIdentifier(contentId: highlight.contentID, sourceId: highlight.sourceID)).count
            object.unreadCount = count
            
            // TODO: Maintain Previous Links
            
            // CRUD
            realm.add(object, update: .all)
            entry.isDeleted = true
        }

        func findOrCreate(_ entry: TaggedHighlight) -> StoredContent {
            let target = realm
                .objects(StoredContent.self)
                .first { $0.id == entry.id }

            if let target {
                return target
            }

            let object = StoredContent()
            object.contentId = entry.contentID
            object.cover = entry.coverURL
            object.title = entry.title
            object.sourceId = entry.sourceID

            realm.add(object, update: .modified)
            return object
        }

        let operations = self.operations
        let libraryStrat = self.libraryStrat
        let lessChapterSrat = self.lessChapterSrat

        func start() {
            for (id, state) in operations {
                if Task.isCancelled {
                    return
                }

                guard let libEntry = get(id) else {
                    continue
                }

                switch state {
                    case .idle, .noMatches, .searching:
                        continue

                    case let .found(result):
                        switch libraryStrat {
                            case .link:
                                link(libEntry, with: result.0)
                            case .replace:
                                replace(libEntry, with: result.0)
                        }
                    case let .lowerFind(result, _, _, _):
                        if lessChapterSrat == .skip { continue }
                        switch libraryStrat {
                            case .link:
                                link(libEntry, with: result)
                            case .replace:
                                replace(libEntry, with: result)
                        }
                }
            }
        }

        do {
            try await realm
                .asyncWrite {
                    start()
                }
        } catch {
            Logger.shared.error(error, "MigrationController")
            ToastManager.shared.error("Migration Failed")
            return false
        }

        ToastManager.shared.info("Migration Complete!")
        return true
    }
}
