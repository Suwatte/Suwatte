//
//  BackupManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift
class BackupManager: ObservableObject {
    static let shared = BackupManager()
    let directory = FileManager.default.documentDirectory.appendingPathComponent("Backups", isDirectory: true)

    init() {
        directory.createDirectory()
        urls = directory.contents.sorted(by: \.lastModified, descending: true)
    }

    @Published var urls: [URL]

    func refresh() {
        urls = directory.contents.sorted(by: \.lastModified, descending: true)
    }

    func save() throws {
        let backup = create()
        let json = try backup.encoded()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy HH:mm:ss"
        let path = directory.appendingPathComponent("STT_BACKUP_\(dateFormatter.string(from: backup.date)).json")
        try json.write(to: path)
        refresh()
    }

    func create() -> Backup {
        let manager = DataManager.shared
        return manager.getAllLibraryObjects()
    }

    func remove(url: URL) {
        try? FileManager.default.removeItem(at: url)
        refresh()
    }

    func `import`(from url: URL) throws {
        let location = directory.appendingPathComponent(url.lastPathComponent)
        if location.exists {
            throw BackUpError.FileExists
        }
        try FileManager.default.copyItem(at: url, to: location)
        refresh()
    }

    func restore(from url: URL) async throws {
        // Load
        var backup: Backup?
        do {
            backup = try Backup.load(from: url)
        } catch {
            print(error)
            throw error
        }

        guard let backup = backup else {
            throw BackUpError.InvalidBackup
        }

        let runners = backup.runners?.map { ($0.id, $0.listURL) } ?? []
        let realm = try await Realm()
        try! realm.safeWrite {
            // Delete old objects
            realm.delete(realm.objects(LibraryEntry.self))
            realm.delete(realm.objects(LibraryCollection.self))
            // Delete all chapter related objects
            realm.delete(realm.objects(ChapterMarker.self))

            realm.delete(realm.objects(Bookmark.self))
            realm.delete(realm.objects(ReadLater.self))
            realm.delete(realm.objects(StoredRunnerList.self))
            realm.delete(realm.objects(StoredRunnerObject.self))

            let downloads = realm
                .objects(ICDMDownloadObject.self)
                .where { $0.status == .completed }
                .map { $0._id } as [String]

            realm.delete(realm.objects(StoredContent.self))
            realm.delete(realm.objects(StoredChapter.self).where { !$0._id.in(downloads) })

            if let libraryEntries = backup.library {
                let contents = libraryEntries.compactMap { $0.content }
                realm.add(contents, update: .all)
                realm.add(libraryEntries)
            }

            if let collections = backup.collections {
                realm.add(collections, update: .all)
            }

            if let markers = backup.markers {
                let chapters = markers.compactMap { $0.chapter }
                // Add
                realm.add(chapters, update: .all)
                realm.add(markers)
            }

            if let bookmarks = backup.bookmarks {
                let markers = bookmarks.compactMap { $0.marker }
                let chapters = markers.compactMap { $0.chapter }
                realm.add(chapters, update: .all)
                realm.add(markers, update: .all)
                realm.add(bookmarks, update: .all)
            }

            if let readLater = backup.savedForLater {
                realm.add(readLater, update: .all)
            }

            if let storedContent = backup.content {
                realm.add(storedContent, update: .all)
            }

            if let runnerLists = backup.runnerLists {
                realm.add(runnerLists, update: .all)
            }
        }

        // Install

        guard !runners.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for runner in runners {
                guard let list = runner.1, let url = URL(string: list)?.sttBase else { return }
                group.addTask {
                    try? await DaisukeEngine.shared.importRunner(from: url, with: runner.0)
                }
            }
        }
    }

    enum BackUpError: Error {
        case FailedToImport, InvalidBackup, EmptyBackup, FileExists
    }
}
