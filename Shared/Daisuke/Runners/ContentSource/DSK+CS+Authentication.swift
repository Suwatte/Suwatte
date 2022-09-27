//
//  DSK+CS+Authentication.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import Foundation
import RealmSwift

extension DSKCommon {
    enum AuthMethod: Int, Codable {
        case username_pw, email_pw, web, oauth

        var isBasic: Bool {
            self == .username_pw || self == .email_pw
        }
    }

    struct User: Parsable, Hashable {
        var id: String
        var username: String
        var avatar: String?
        var info: [String]?
    }
}

// MARK: Get Auth Method

extension DSK.ContentSource {
    func getAuthenticatedUser() async throws -> DSKCommon.User? {
        try await withCheckedThrowingContinuation { handler in
            let method = "getAuthenticatedUser"
            guard runnerClass.hasProperty(method) else {
                handler.resume(throwing: DaisukeEngine.Errors.MethodNotFound(name: method))
                return
            }

            runnerClass.daisukeCall(method: method, arguments: []) { value in
                if value.isNull {
                    handler.resume(returning: nil)
                    return
                }
                do {
                    let object = try DSKCommon.User(value: value)
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

extension DSK.ContentSource {
    func handleUserSignOut() async throws {
        try await callOptionalVoidMethod(method: "handleUserSignOut", arguments: [])
    }
}

extension DSK.ContentSource {
    func handleBasicAuth(id: String, password: String) async throws {
        if !methodExists(method: "handleBasicAuth") {
            throw DSK.Errors.NamedError(name: "Implementation Error", message: "Source Author has not implemented the required handleBasicAuth Method. Please reach out to the maintainer")
        }
        try await callOptionalVoidMethod(method: "handleBasicAuth", arguments: [id, password])
    }
}


// MARK: Sync

extension DSK.ContentSource {
    
    func syncUserLibrary() async throws {
        let method = "syncUserLibrary"
        if !methodExists(method: method) {
            throw DSK.Errors.MethodNotImplemented
            
        }
        
        
        let realm = try! Realm(queue: nil)
        
        let library: [DSKCommon.UpSyncedContent] = realm
            .objects(LibraryEntry.self)
            .where({ $0.content.sourceId == id })
            .where({ $0.content != nil })
            .map({ .init(id: $0.content!.contentId, flag: $0.flag) })
        let data = try  DaisukeEngine.encode(value: library)
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


extension DataManager {
    func downSyncLibrary(entries: [DSKCommon.DownSyncedContent], sourceId: String) {
        let realm = try! Realm()
        
        try! realm.safeWrite {
            for entry in entries {
                
                let libraryTarget = realm.objects(LibraryEntry.self)
                    .where { $0.content.contentId == entry.id }
                    .where { $0.content.sourceId == sourceId }
                    .first
                
                // Title, In Library, Update Flag
                if let libraryTarget, let flag = entry.readingFlag {
                    libraryTarget.flag = flag
                    continue
                }
                
                // Not In Library, Find/Create Stored then save
                var currentStored = realm
                    .objects(StoredContent.self)
                    .where { $0.contentId == entry.id }
                    .where { $0.sourceId == sourceId }
                    .first
                if currentStored == nil {
                    currentStored = StoredContent()
                    currentStored?._id = "\(sourceId)||\(entry.id)"
                    currentStored?.contentId = entry.id
                    currentStored?.sourceId = sourceId
                    currentStored?.title = entry.title
                    currentStored?.cover = entry.cover
                }
                guard let currentStored = currentStored else {
                    return
                }

                realm.add(currentStored, update: .modified)
                let libraryObject = LibraryEntry()
                libraryObject.content = currentStored
                if let flag = entry.readingFlag {
                    libraryObject.flag = flag
                }
                realm.add(libraryObject)
            }
        }
    }
}
