//
//  DSK+CS+Sync.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-16.
//

import Foundation
import RealmSwift

extension DSK.LocalContentSource {
    func getReadChapterMarkers(for id: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { handler in
            let methodName = "getReadChapterMarkers"
            guard methodExists(method: methodName) else {
                handler.resume(throwing: DSK.Errors.MethodNotFound(name: methodName))
                return
            }

            runnerClass.daisukeCall(method: methodName, arguments: [id]) { value in
                guard let value = value.toArray() as? [String] else {
                    handler.resume(throwing: DSK.Errors.ObjectConversionFailed)
                    return
                }
                handler.resume(returning: value)
            } onFailure: { error in
                handler.resume(throwing: error)
            }
        }
    }
}

// MARK: Sync

extension DSK.LocalContentSource {
    func syncUserLibrary() async throws {
        let method = "syncUserLibrary"
        if !methodExists(method: method) {
            throw DSK.Errors.MethodNotImplemented
        }

        let realm = try! Realm(queue: nil)

        let library: [DSKCommon.UpSyncedContent] = realm
            .objects(LibraryEntry.self)
            .where { $0.content.sourceId == id }
            .where { $0.content != nil }
            .map { .init(id: $0.content!.contentId, flag: $0.flag) }
        let data = try DaisukeEngine.encode(value: library)
        let arr = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String: Any]]
        guard let arr = arr else {
            throw DSK.Errors.ObjectConversionFailed
        }
        let downSyncedTitles = try await callMethodReturningDecodable(method: method,
                                                                      arguments: [arr as Any],
                                                                      resolvesTo: [DSKCommon.DownSyncedContent].self)

        DataManager.shared.downSyncLibrary(entries: downSyncedTitles, sourceId: id)
    }
}

