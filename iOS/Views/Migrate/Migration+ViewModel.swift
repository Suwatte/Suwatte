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
            for item in cases {
                operations.removeValue(forKey: item)
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
                    if !singleSourceMigration, id == value.entry.id {
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

        let chapters = await getChapters(for: source, id: contentId)

        let target = chapters?.first

        guard let target else { return nil }

        if var chapters = chapters {
            chapters = STTHelpers.filterChapters(chapters, with: .init(contentId: contentId, sourceId: source.id))
            await storeChapters(chapters: chapters
                .map { $0.toStoredChapter(sourceID: source.id, contentID: contentId) })
        }

        return (TaggedHighlight(from: result, with: source.id), target.number, chapters?.count ?? 0)
    }

    func storeChapters(chapters: [StoredChapter]) async {
        let actor = await RealmActor.shared()
        await actor.storeChapters(chapters)
    }

    func getChapters(for sourceId: String, id: String) async -> [DSKCommon.Chapter]? {
        guard let source = sources[sourceId] else {
            return nil
        }

        return await getChapters(for: source, id: id)
    }

    private func getChapters(for source: AnyContentSource, id: String) async -> [DSKCommon.Chapter]? {
        let content = try? await source.getContent(id: id)
        guard let content else { return nil }

        var chapters = content.chapters

        if chapters == nil {
            chapters = (try? await source.getContentChapters(contentId: id))
        }

        return chapters
    }

    func getStoredChapterCount(for content: TaggedHighlight) async -> Int {
        let actor = await RealmActor.shared()
        return await actor.getStoredChapterCount(content.sourceID, content.contentID)
    }
}


final actor InnerMigrationActor {
    var operations: [String: MigrationItemState] = [:]
    var libraryStrat: LibraryMigrationStrategy
    var lessChapterSrat: LowerChapterMigrationStrategy
    var realm: Realm!
    init(operations: [String: MigrationItemState], libStrat: LibraryMigrationStrategy, lessChStrat: LowerChapterMigrationStrategy) async throws {
        self.operations = operations
        self.libraryStrat = libStrat
        self.lessChapterSrat = lessChStrat
    }
}
// MARK: - MigrationController refactor (synchronous writes)
extension InnerMigrationActor {

    // MARK: – Public entry‑point

    func migrate() async -> Bool {
        defer { Task { @MainActor in ToastManager.shared.loading = false } }
        self.realm = try! await Realm(actor: self)

        await migrate_showLoadingToast()

        guard await migrate_runBackup() else { return false }


        do {
            try realm.write {
                migrate_start(
                    operations: self.operations,
                    libraryStrat: self.libraryStrat,
                    lessChapterSrat: self.lessChapterSrat
                )
            }
        } catch {
            Logger.shared.error(error, "MigrationController")
            ToastManager.shared.error("Migration Failed")
            return false
        }

        ToastManager.shared.info("Migration Complete!")
        return true
    }

    // MARK: – Top‑level helpers

    @MainActor
    private func migrate_showLoadingToast() async {
        ToastManager.shared.loading = true
        ToastManager.shared.info("Migration In Progress\nYour Data is being backed up.")
    }

    private func migrate_runBackup() async -> Bool {
        do {
            try await BackupManager.shared.save(name: "PreMigration")
            return true
        } catch {
            Task { @MainActor in ToastManager.shared.error(error) }
            return false
        }
    }

    // MARK: – Core loop (executed inside the single write)

    private func migrate_start(
        operations: [String: MigrationItemState],
        libraryStrat: LibraryMigrationStrategy,
        lessChapterSrat: LowerChapterMigrationStrategy
    ) {
        for (id, state) in operations {
            if Task.isCancelled { return }

            guard let libEntry = migrate_get(id, in: realm) else { continue }

            switch state {
            case .idle, .noMatches, .searching:
                continue

            case let .found(result, _):
                switch libraryStrat {
                case .link:    migrate_link(libEntry, with: result)
                case .replace: migrate_replace(libEntry, with: result)
                }

            case let .lowerFind(result, _, _, _):
                if lessChapterSrat == .skip { continue }
                switch libraryStrat {
                case .link:    migrate_link(libEntry, with: result)
                case .replace: migrate_replace(libEntry, with: result)
                }
            }
        }
    }

    // MARK: – Extracted helpers (bodies unchanged)

    private func migrate_get(_ id: String, in realm: Realm) -> LibraryEntry? {
        realm.object(ofType: LibraryEntry.self, forPrimaryKey: id)
    }

    private func migrate_link(
        _ entry: LibraryEntry,
        with highlight: TaggedHighlight
    ) {
        let one = entry.id
        let two = highlight.id
        if one == two { return }

        let isAlreadyLinked = !realm
            .objects(ContentLink.self)
            .where { $0.entry.id == one && $0.content.id == two && $0.isDeleted == false }
            .isEmpty
        if isAlreadyLinked { return }

        let object = ContentLink()
        object.entry   = entry
        object.content = migrate_findOrCreate(highlight)
        realm.add(object, update: .modified)
    }

    private func migrate_remove(_ entry: LibraryEntry) {
        entry.isDeleted = true
    }

    private func migrate_replace(
        _ entry: LibraryEntry,
        with highlight: TaggedHighlight
    ) {
        let object = LibraryEntry()
        object.content     = migrate_findOrCreate(highlight)
        object.collections = entry.collections
        object.flag = entry.flag
        object.dateAdded = entry.dateAdded

        let progressMarkers = realm
            .objects(ProgressMarker.self)
            .where { $0.chapter.content.sourceId == entry.content!.sourceId &&
                $0.chapter.content.contentId == entry.content!.contentId &&
                !$0.isDeleted
            }
            .freeze()
            .toArray()

        let highlightChapters = realm
            .objects(StoredChapter.self)
            .where { $0.contentId == highlight.contentID }
            .where { $0.sourceId == highlight.sourceID }
            .freeze()
            .toArray()

        // Update Read Chapters
        let readChaptersByOrderKey = progressMarkers
            .filter { $0.isCompleted }
            .map { $0.chapter!.chapterOrderKey }

        let readChaptersByNumber: [Double] = readChaptersByOrderKey.compactMap { chapterOrderKey in
            let chapterNumber = ThreadSafeChapter.orderKey(
                volume: nil,
                number: ThreadSafeChapter.vnPair(from: chapterOrderKey).1
            )
            guard let chapterRef = highlightChapters
                .first(where: { $0.chapterOrderKey == chapterNumber }) else { return nil }

            let reference: ChapterReference? = chapterRef.generateReference()
            let content = realm.object(ofType: StoredContent.self, forPrimaryKey: chapterRef.contentIdentifier.id)
            if let content, !content.isDeleted {
                reference?.content = content
            }

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

        // Get All Unread
        let unreadChapters = highlightChapters
            .filter { !readChaptersByNumber.contains($0.chapterOrderKey) }
            .distinct(by: \.number)
            .map { $0.toThreadSafe() }

        // Apply Filter
        let count = STTHelpers.filterChapters(
            unreadChapters,
            with: ContentIdentifier(
                contentId: highlight.contentID,
                sourceId: highlight.sourceID
            )
        ).count
        object.unreadCount = count

        // TODO: Maintain Previous Links

        // CRUD
        realm.add(object, update: .all)

        if object.id != entry.id { entry.isDeleted = true }
    }

    private func migrate_findOrCreate(
        _ entry: TaggedHighlight
    ) -> StoredContent {
        if let target = realm.object(ofType: StoredContent.self, forPrimaryKey: entry.id) { return target }


        let object = StoredContent()
        object.contentId = entry.contentID
        object.cover = entry.coverURL
        object.title = entry.title
        object.sourceId = entry.sourceID

        realm.add(object, update: .modified)
        return object
    }
}
