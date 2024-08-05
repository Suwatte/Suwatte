//
//  CPVM+Network.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation

private typealias ViewModel = ProfileView.ViewModel

extension ViewModel {
    func getContentFromSource() async throws -> DSKCommon.Content {
        try await source
            .getContent(id: entry.id)
    }

    func getChaptersFromSource() async throws -> [DSKCommon.Chapter] {
        try await source
            .getContentChapters(contentId: entry.id)
    }

    func getPreparedChapters(chapters: [DSKCommon.Chapter]) -> [ThreadSafeChapter] {
        return chapters
            .sorted(by: \.index, descending: false)
            .map { $0.toThreadSafe(sourceID: source.id, contentID: entry.id) }
    }
}

extension ViewModel {}
