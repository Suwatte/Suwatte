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
                    operations[result.0] = result.1
                }
            }
        }

        await MainActor.run(body: {
            operationState = .searchComplete
        })
    }

    private typealias ReturnValue = (TaggedHighlight, Double)
    private func handleSourcesSearch(id: String, query: String, chapter: Double?, sources: [AnyContentSource]) async -> (String, MigrationItemState) {
        await withTaskGroup(of: ReturnValue?.self, body: { group in

            for source in sources {
                guard !Task.isCancelled else { return (id, .idle) }
                group.addTask { [weak self] in
                    await self?.searchSource(query: query, chapter: chapter, source: source)
                }
            }

            var max: ReturnValue?
            for await value in group {
                if let value {
                    // Chapter matches
                    let currentChapterNumber = max?.1 ?? 0
                    let matches = value.1 >= currentChapterNumber

                    if matches {
                        if let cId = max?.0.sourceID {
                            let index = sources.firstIndex(where: { $0.id == value.0.sourceID }) ?? Int.max
                            let currentIndex = sources.firstIndex(where: { $0.id == cId }) ?? Int.max

                            if index < currentIndex {
                                max = value
                            }
                        } else {
                            if currentChapterNumber < value.1 {
                                max = value
                            }
                        }
                    }
                }
            }

            if let max {
                if max.1 >= (chapter ?? 0) {
                    return (id, .found(max.0))
                } else {
                    return (id, .lowerFind(max.0, chapter ?? 0, max.1))
                }
            } else {
                return (id, .noMatches)
            }
        })
    }

    private func searchSource(query: String, chapter: Double?, source: AnyContentSource) async -> ReturnValue? {
        let data: DSKCommon.PagedResult<DSKCommon.Highlight>? = try? await source.getDirectory(request: .init(query: query, page: 1))
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

        guard let target, let chapter, target.number >= chapter else { return nil }

        return (TaggedHighlight(from: result, with: source.id), target.number)
    }

    private func getChapters(for source: AnyContentSource, id: String) async -> [DSKCommon.Chapter] {
        (try? await source.getContentChapters(contentId: id)) ?? []
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
            let isAlreadyLinked = !realm
                .objects(ContentLink.self)
                .where { $0.ids.contains(one) && $0.ids.contains(two) && $0.isDeleted == false }
                .isEmpty

            if isAlreadyLinked {
                return
            }

            let target = realm
                .objects(ContentLink.self)
                .where { $0.ids.containsAny(in: [one, two]) && $0.isDeleted == false }
                .first

            // A or B already in a linkset
            if let target {
                target.ids.insert(one)
                target.ids.insert(two)
            } else {
                let object = ContentLink()
                object.ids.insert(one)
                object.ids.insert(two)
                realm.add(object, update: .modified)
            }
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

            // CRUD
            realm.add(object, update: .all)
            entry.isDeleted = true
        }

        func findOrCreate(_ entry: TaggedHighlight) -> StoredContent {
            let target = realm
                .objects(StoredContent.self)
                .where { $0.id == entry.id }
                .first

            if let target {
                return target
            }

            let object = StoredContent()
            object.contentId = entry.contentID
            object.cover = entry.coverURL
            object.title = entry.title
            object.sourceId = entry.sourceID

            realm.add(object)
            return object
        }

        let operations = self.operations
        let libraryStrat = self.libraryStrat
        let lessChapterSrat = self.lessChapterSrat

        func start() {
            for (id, state) in operations {
                if Task.isCancelled { return }
                guard let libEntry = get(id) else { continue }
                switch state {
                case .idle, .noMatches, .searching:
                    continue

                case let .found(result):
                    switch libraryStrat {
                    case .link:
                        link(libEntry, with: result)
                    case .replace:
                        replace(libEntry, with: result)
                    }
                case let .lowerFind(result, _, _):
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
