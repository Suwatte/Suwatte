//
//  Migration+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-27.
//

import Foundation
import SwiftUI

enum LibraryMigrationStrategy: CaseIterable {
    case link, replace

    var description: String {
        switch self {
        case .link: return "Link"
        case .replace: return "Replace"
        }
    }
}

enum NotFoundMigrationStrategy: CaseIterable {
    case remove, skip
    var description: String {
        switch self {
        case .remove: return "Remove"
        case .skip: return "Skip"
        }
    }
}

enum LowerChapterMigrationStrategy: CaseIterable {
    case skip, migrate

    var description: String {
        switch self {
        case .migrate: return "Migrate Anyway"
        case .skip: return "Skip"
        }
    }
}


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

extension MigrationController {
    func loadSources() async {
        let sources = await DSK
            .shared
            .getActiveSources()
            .filter { $0.ablityNotDisabled(\.disableMigrationDestination)}
        var nonIsolatedDict: Dictionary<String, AnyContentSource> = [:]
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
    func migrate() async {}
    
    func cancelOperations() {
        operationsTask?.cancel()
        operationsTask = nil
    }

    func removeItem(id: String) {
        contents.removeAll(where: { $0.id == id })
        operations.removeValue(forKey: id)
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

        contents.removeAll(where: { cases.contains($0.id) })
        cases.forEach {
            operations.removeValue(forKey: $0)
        }
    }
}



extension MigrationController {
    func search() async {
        await MainActor.run(body: {
            operationState = .searching
        })

        let actor = await RealmActor()
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
        let content = try? await source.getContent(id: result.contentId)
        guard let content else { return nil }

        var chapters = content.chapters

        if chapters == nil {
            chapters = await getChapters(for: source, id: content.contentId)
        }

        let target = chapters?.first

        guard let target, let chapter, target.number >= chapter else { return nil }

        
        return (TaggedHighlight(from: result, with: source.id), target.number)
    }

    private func getChapters(for source: AnyContentSource, id: String) async -> [DSKCommon.Chapter] {
        (try? await source.getContentChapters(contentId: id)) ?? []
    }
}



//extension MigrationView {
//
//    func migrate(data _: [String: ItemState]) {
//        Task { @MainActor in
//            ToastManager.shared.loading = true
//            ToastManager.shared.info("Migration In Progress\nYour Data has been backed up.")
//        }
//
//        do {
//            try BackupManager.shared.save(name: "PreMigration")
//        } catch {
//            Task { @MainActor in
//                ToastManager.shared.error(error)
//            }
//            return
//        }
//
////        let realm = try! Realm()
//
////        func doMigration(entry: HighlightIdentifier, target: LibraryEntry) {
////            var stored = realm
////                .objects(StoredContent.self)
////                .where { $0.contentId == entry.entry.contentId }
////                .where { $0.sourceId == entry.sourceId }
////                .where { $0.isDeleted == false }
////                .first
////
////            stored = stored ?? entry.entry.toStored(sourceId: entry.sourceId)
////            guard let stored else { return }
////
////            switch libraryStrat {
////            case .link:
////                guard let content = target.content else { return }
////                _ = DataManager.shared.linkContent(stored.id, content.id)
////            case .replace:
////                let obj = LibraryEntry()
////                obj.content = stored
////                obj.collections = target.collections
////                obj.flag = target.flag
////                obj.dateAdded = target.dateAdded
////                realm.add(obj, update: .modified)
////
////                if target.id != obj.id {
////                    target.isDeleted = true
////                }
////            }
////        }
////        try! realm.safeWrite {
////            for (id, state) in data {
////                let target = realm
////                    .objects(LibraryEntry.self)
////                    .where { $0.id == id }
////                    .where { $0.isDeleted == false }
////                    .first
////                guard let target else { continue }
////                switch state {
////                case let .found(entry):
////                    doMigration(entry: entry, target: target)
////                case let .lowerFind(entry, _, _):
////                    if lessChapterSrat == .skip { continue }
////                    doMigration(entry: entry, target: target)
////                default:
////                    if notFoundStrat == .remove {
////                        target.isDeleted = true
////                    }
////                }
////            }
////        }
////        Task { @MainActor in
////            ToastManager.shared.loading = false
////            ToastManager.shared.cancel()
////            ToastManager.shared.info("Migration Complete!")
////            presentationMode.wrappedValue.dismiss()
////        }
//    }
//}
