//
//  SearchView+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-02.
//

import SwiftUI
import RealmSwift


extension SearchView {
    typealias PagedResult = DSKCommon.PagedHighlight

    struct ResultGroup {
        let sourceID: String
        let sourceName: String
        let result: PagedResult
    }
    
    struct IncompleteSources {
        var failing: [String]
        var noResults: [String]
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
        @Published var savedForLater: Set<String> = []
        
        private let isContentLinkModel: Bool
        
        private var libraryToken : NotificationToken?
        private var readLaterToken: NotificationToken?
        
        init(forLinking: Bool = false) {
            self.isContentLinkModel = forLinking
        }

        private func getSources () async -> [JSCCS] {
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

        func load(for source: JSCCS) async {
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
            
            let actor = await RealmActor()
            libraryToken = await actor.observeLibraryIDs { value in
                self.library = value
            }
            
            readLaterToken = await actor.observeReadLaterIDs { value in
                self.savedForLater = value
            }
        }
        
        func stopObserving() {
            libraryToken?.invalidate()
            libraryToken = nil
            
            readLaterToken?.invalidate()
            readLaterToken = nil
        }
    }
}


