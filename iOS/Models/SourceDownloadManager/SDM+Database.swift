//
//  SDM+Database.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation
import RealmSwift

enum DownloadStatus: Int, PersistableEnum {
    case idle, active, queued, failing, completed, paused, cancelled
}

// MARK: Queue Helpers

extension SDM {
    func fetchQueue() {
        let realm = try! Realm()
        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.status == .queued }
            .sorted(by: \.dateAdded, ascending: true)
            .freeze()
            .toArray()

        setQueue(collection)
    }

    func update(ids: [String], status: DownloadStatus) {
        let realm = try! Realm()
        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.id.in(ids) }

        try! realm.safeWrite {
            for download in collection {
                download.status = status
            }
        }
        fetchQueue()
    }

    func add(chapters: [String]) {
        let realm = try! Realm()

        // Get completed download ids
        let completed = realm
            .objects(SourceDownload.self)
            .where { $0.id.in(chapters) && $0.status == .completed }
            .map(\.id) as [String]

        // Get Stored Chapters
        let chapters = realm
            .objects(StoredChapter.self)
            .where { !$0.id.in(completed) } // Filter out Completed Downloads
            .where { $0.id.in(chapters) }
            .sorted(by: \.index, ascending: false)

        // Get the selected contents
        let contentIDs = Set(chapters.map(\.contentIdentifier.id))

        let contents = realm
            .objects(StoredContent.self)
            .where { $0.id.in(contentIDs) }
            .toArray()

        // create dictionary of content in ID: OBJECT
        let contentMap = Dictionary(uniqueKeysWithValues: contents.map { ($0.id, $0) })

        // Create download objects for chapters
        let downloads = chapters
            .map { chapter -> SourceDownload in
                let download = SourceDownload()
                download.id = chapter.id
                download.chapter = chapter
                download.content = contentMap[chapter.contentIdentifier.id]
                download.status = .queued
                download.dateAdded = .now
                return download
            }

        // Update in DB
        try! realm.safeWrite {
            realm.add(downloads, update: .modified)
        }
        return // Remove
        if queue.isEmpty {
            fetchQueue()
        }
    }

    func get(_ id: String) -> SourceDownload? {
        let realm = try! Realm()

        let target = realm
            .objects(SourceDownload.self)
            .where { $0.id == id }
            .first

        return target?.freeze()
    }

    func get(_ ids: [String]) -> [SourceDownload] {
        let realm = try! Realm()

        let targets = realm
            .objects(SourceDownload.self)
            .where { $0.id.in(ids) }
            .freeze()
            .toArray()

        return targets
    }

    func get(_ status: DownloadStatus) -> [SourceDownload] {
        let realm = try! Realm()

        let targets = realm
            .objects(SourceDownload.self)
            .where { $0.status == status }
            .freeze()
            .toArray()

        return targets
    }

    func finished(_ id: String, url: URL) {
        let realm = try! Realm()

        let target = realm
            .objects(SourceDownload.self)
            .where { $0.id == id }
            .first
        guard let target else {
            Logger.shared.warn("Trying to update a download that does not exist (\(id))", CONTEXT)
            return
        }

        // Point Archive
        if url.isFileURL, !url.hasDirectoryPath {
            try! realm.safeWrite {
                target.archive = url.lastPathComponent
            }
        }

        if let content = target.content {
            updateIndex(of: content)
        }

        Logger.shared.log("Operation Complete (\(id))")
    }
}

//
extension SDM {
    func resume(ids: [String]) {
        update(ids: ids, status: .queued)
        pausedTasks = pausedTasks.subtracting(ids)
    }

    func pause(ids: [String]) {
        update(ids: ids, status: .paused)
        pausedTasks = pausedTasks.union(ids)
    }

    func cancel(ids: [String]) {
        let collection = get(ids)
        let completed = collection
            .filter { $0.status == .completed }
            .map(\.id)
        let archives = collection.compactMap(\.archive)

        update(ids: ids, status: .cancelled)

        archivesMarkedForDeletion = archivesMarkedForDeletion.union(archives)
        foldersMarkedForDeletion = foldersMarkedForDeletion.union(completed)
        cancelledTasks = cancelledTasks.union(ids)

        if isIdle {
            clean()
        }
    }

    func delete(ids: [String]) {
        let realm = try! Realm()

        let targets = realm
            .objects(SourceDownload.self)
            .where { $0.id.in(ids) }

        try! realm.safeWrite {
            realm.delete(targets)
        }
    }

    func reattach() {
        // Called when restarted, requeue failing downloads
        let failing = get(.failing)
        let cancelled = get(.cancelled)
        let active = get(.active)

        cancelledTasks = cancelledTasks.union(cancelled.map(\.id)) // Set cancelled tasks to cache, will be clean at next possible interval
        update(ids: active.map(\.id), status: .queued) // Update prior active tasks to now be requeued
        update(ids: failing.map(\.id), status: .queued) // update prior failing tasks to be requeued
    }
}

extension SDM {
    func setText(_ id: String, _ text: String) {
        let realm = try! Realm()
        let download = realm
            .objects(SourceDownload.self)
            .where { $0.id == id }
            .first

        guard let download else {
            Logger.shared.warn("Trying to update a download that does not exist (\(id))", CONTEXT)
            return
        }

        try! realm.safeWrite {
            download.text = text
        }
    }
}

// MARK: File Removal

extension SDM {
    func buildArchive(_ name: String) -> URL {
        directory
            .appendingPathComponent("Archives", isDirectory: true)
            .appendingPathComponent(name)
    }

    func removeArchive(at url: URL) {
        guard url.exists else {
            Logger.shared.warn("Trying to remove a file that does not exist, \(url.fileName)", CONTEXT)
            return
        }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Logger.shared.error(error, CONTEXT)
        }
    }

    func removeDirectory(at url: URL) {
        guard url.exists, url.hasDirectoryPath else {
            Logger.shared.warn("Trying to remove a file that does not exist, \(url.fileName)", CONTEXT)
            return
        }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Logger.shared.error(error, CONTEXT)
        }
    }
}

extension DataManager {
    func getActiveDownload(_ id: String) -> SourceDownload? {
        let realm = try! Realm()

        return realm
            .objects(SourceDownload.self)
            .where { $0.content != nil && $0.chapter != nil }
            .where { $0.id == id && $0.status == .active }
            .first?
            .freeze()
    }
}
