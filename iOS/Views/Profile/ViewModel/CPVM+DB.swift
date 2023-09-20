//
//  CPVM+DB.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation

private typealias ViewModel = ProfileView.ViewModel

// MARK: Get

extension ViewModel {
    func getContentFromDatabase() async -> DSKCommon.Content? {
        // Load From DB
        let actor = await RealmActor.shared()

        Task { @MainActor [weak self] in
            self?.contentState = .loading
        }

        let target = await actor
            .getDSKContent(identifier)

        return target
    }

    func getChaptersFromDatabase() async -> [StoredChapter]? {
        let actor = await RealmActor.shared()

        let chapters = await actor.getChapters(source.id,
                                               content: entry.id)

        if chapters.isEmpty { return nil }
        return chapters
    }
}

// MARK: Set

extension ViewModel {
    func saveContent(_ content: DSKCommon.Content) async {
        do {
            let content = try content.toStoredContent(with: .init(contentId: entry.id, sourceId: sourceID))
            let actor = await RealmActor.shared()
            await actor.storeContent(content)
        } catch {
            Logger.shared.error(error, "Save Content")
        }
    }

    func saveChapters(_ chapters: [DSKCommon.Chapter]) async {
        let chapters = chapters.map { $0.toStoredChapter(sourceID: sourceID, contentID: contentID) }
        let actor = await RealmActor.shared()
        await actor.storeChapters(chapters)
    }
}
