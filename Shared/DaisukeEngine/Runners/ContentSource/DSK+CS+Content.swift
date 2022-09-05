//
//  DSK+CS+Content.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation

// MARK: Get Content

extension DaisukeEngine.ContentSource {
    func getContent(id: String) async throws -> DaisukeEngine.Structs.Content {
        try await callMethodReturningObject(method: "getContent", arguments: [id], resolvesTo: DaisukeEngine.Structs.Content.self)
    }
}

// MARK: Chapters

extension DaisukeEngine.ContentSource {
    func getContentChapters(contentId: String) async throws -> [DaisukeEngine.Structs.Chapter] {
        try await callMethodReturningDecodable(method: "getChapters", arguments: [contentId], resolvesTo: [DaisukeEngine.Structs.Chapter].self)
    }

    func getChapterData(contentId: String, chapterId: String) async throws -> DaisukeEngine.Structs.ChapterData {
        try await callMethodReturningObject(method: "getChapterData", arguments: [contentId, chapterId], resolvesTo: DaisukeEngine.Structs.ChapterData.self)
    }

    func getIdentifiers(for url: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer? {
        try await withCheckedThrowingContinuation { handler in
            guard runnerClass.hasProperty("handleIdentifierForUrl") else {
                handler.resume(returning: nil)
                return
            }

            runnerClass.daisukeCall(method: "handleIdentifierForUrl", arguments: [url]) { value in
                if value.isNull {
                    handler.resume(returning: nil)
                }

                do {
                    let object = try DaisukeEngine.Structs.URLContentIdentifer(value: value)
                    handler.resume(returning: object)

                } catch {
                    handler.resume(throwing: error)
                }

            } onFailure: { error in
                handler.resume(throwing: error)
            }
        }
    }
}
