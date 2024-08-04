//
//  SearchView+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-02.
//

import RealmSwift
import SwiftUI

extension SearchView {
    typealias PagedResult = DSKCommon.PagedResult

    struct ResultGroup: Hashable {
        let sourceID: String
        let sourceName: String
        var result: PagedResult
    }

    struct IncompleteSources: Hashable {
        var failing: [String]
        var noResults: [String]

        var hasIncomplete: Bool {
            !failing.isEmpty || !noResults.isEmpty
        }
    }

    @MainActor
    final class ViewModel: ObservableObject {
        @Published var query = ""
        // Get Sources Filtered for Global Search
        @Published var results = [ResultGroup]()
        @Published var state = Loadable<String>.idle
        @Published var history: [UpdatedSearchHistory] = []
        @Published var incomplete: IncompleteSources = .init(failing: [], noResults: [])
        @Published var library: Set<String> = []
        @Published var libraryLinked: Set<String> = []
        @Published var savedForLater: Set<String> = []

        private let isContentLinkModel: Bool
        private var libraryToken: NotificationToken?
        private var libraryLinkedToken: NotificationToken?
        private var readLaterToken: NotificationToken?
        private var preSources: [AnyContentSource]?
        init(forLinking: Bool = false, preSources: [AnyContentSource]? = nil) {
            isContentLinkModel = forLinking
            self.preSources = preSources
        }

        private func getSources() async -> [AnyContentSource] {
            if let preSources {
                return preSources
            }
            let engine = DSK.shared
            let sources = await isContentLinkModel ? engine.getSourcesForLinking() : engine.getSourcesForSearching()
            return sources
        }

        func makeRequests() async {
            await MainActor.run {
                state = .loading
                results.removeAll()
                incomplete = .init(failing: [], noResults: [])
            }

            let sources = await getSources()

            guard !Task.isCancelled else { return }
            await withTaskGroup(of: Void.self) { group in
                for source in sources {
                    guard !Task.isCancelled else { return }
                    group.addTask {
                        await self.load(for: source)
                    }
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                state = .loaded("")
            }
        }

        func removeContentFromResult(contentIdentifier: ContentIdentifier) {
            if results.isEmpty {
                return
            }

            var resultGroupsToClean: [Int] = []

            for resultGroup in results {
                if resultGroup.sourceID != contentIdentifier.sourceId {
                    continue
                }

                let pagedResult = resultGroup.result
                var pagedResults = pagedResult.results
                pagedResults.removeAll { $0.id == contentIdentifier.contentId }

                if pagedResults.isEmpty {
                    resultGroupsToClean.append(resultGroup.hashValue)
                }
            }

            if !resultGroupsToClean.isEmpty {
                results.removeAll { resultGroupsToClean.contains($0.hashValue) }
            }
        }

        func load(for source: AnyContentSource) async {
            let request = DSKCommon.DirectoryRequest(query: query, page: 1)
            do {
                let data: PagedResult = try await source.getDirectory(request: request)

                await MainActor.run {
                    if data.results.isEmpty {
                        incomplete.noResults.append(source.name)
                    } else {
                        let result: ResultGroup = .init(sourceID: source.id, sourceName: source.name, result: data)
                        results.append(result)
                    }
                }

            } catch {
                await MainActor.run {
                    incomplete.failing.append(source.name)
                }
                Logger.shared.error(error, source.id)
            }
        }

        func observe() async {
            guard libraryToken == nil, readLaterToken == nil else { return }

            let actor = await RealmActor.shared()
            libraryToken = await actor.observeLibraryIDs { value in
                self.library = value
            }

            libraryLinkedToken = await actor.observeLinkedIDs { value in
                self.libraryLinked = value
            }

            readLaterToken = await actor.observeReadLaterIDs { value in
                self.savedForLater = value
            }
        }

        func stopObserving() {
            libraryToken?.invalidate()
            libraryToken = nil

            libraryLinkedToken?.invalidate()
            libraryLinkedToken = nil

            readLaterToken?.invalidate()
            readLaterToken = nil
        }
    }
}
