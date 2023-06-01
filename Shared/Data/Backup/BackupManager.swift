//
//  BackupManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift
class BackupManager: ObservableObject {
    private var observer: DispatchSourceFileSystemObject?

    static let shared = BackupManager()
    let directory = CloudDataManager.shared.getDocumentDiretoryURL().appendingPathComponent("Backups", isDirectory: true)
    @Published var urls: [URL]

    init() {
        directory.createDirectory()
        urls = directory.contents.sorted(by: \.lastModified, descending: true)
    }
    
    deinit {
        observer?.cancel()
    }
    // Reference: https://medium.com/over-engineering/monitoring-a-folder-for-changes-in-ios-dc3f8614f902
    func observeDirectory() {
        let descriptor = open(directory.path, O_EVTONLY)
        let observer = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .global(qos: .utility))
        observer.setEventHandler { [weak self] in
            Logger.shared.log("[Backups] Handling Event")
            self?.refresh()
        }

        observer.setRegistrationHandler { [weak self] in
            Logger.shared.log("[Backups] Observing Directory")
            self?.refresh()
        }

        observer.setCancelHandler {
            Logger.shared.log("[Buckups] Closing Observer")
            close(descriptor)
        }
        
        observer.resume()
        self.observer = observer
    }
    
    func stopObserving() {
        observer?.cancel()
    }



    
    func refresh() {
        let urls =  directory
            .contents
            .sorted(by: \.lastModified, descending: true)
            .filter({ ["json", "icloud" ].contains($0.pathExtension) })
        Task { @MainActor in
            self.urls = urls
        }
    }

    func save(name: String? = nil) throws {
        let backup = create()
        let json = try backup.encoded()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy HH:mm:ss"
        let name = name ?? .random(length: 5)
        let path = directory.appendingPathComponent("STT_BACKUP_\(name)_\(dateFormatter.string(from: backup.date)).json")
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

    private func restoreDB(backup: Backup) {
        let realm = try! Realm()
        try! realm.safeWrite {
            // Delete old objects
            realm.delete(realm.objects(LibraryEntry.self))
            realm.delete(realm.objects(LibraryCollection.self))
            realm.delete(realm.objects(Bookmark.self))
            realm.delete(realm.objects(ReadLater.self))
            realm.delete(realm.objects(StoredRunnerList.self))
            realm.delete(realm.objects(StoredRunnerObject.self))

            let downloads = realm
                .objects(ICDMDownloadObject.self)
                .where { $0.status == .completed }
                .map { $0._id } as [String]

            realm.delete(realm.objects(StoredContent.self))
            realm.delete(realm.objects(StoredChapter.self).where { !$0.id.in(downloads) })

            if let libraryEntries = backup.library {
                let contents = libraryEntries.compactMap { $0.content }
                realm.add(contents, update: .all)
                realm.add(libraryEntries)
            }

            if let collections = backup.collections {
                realm.add(collections, update: .all)
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
    }

    func restore(from url: URL) async throws {
        // Load
        var backup: Backup?
        do {
            backup = try Backup.load(from: url)
        } catch {
            Logger.shared.error("[Backups] \(error.localizedDescription)")
            throw error
        }

        guard let backup = backup else {
            throw BackUpError.InvalidBackup
        }

        let runners = backup.runners?.map { ($0.id, $0.listURL) } ?? []

        // Install
        restoreDB(backup: backup)

        guard !runners.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for runner in runners {
                guard let url = URL(string: runner.1) else { return }
                group.addTask {
                    do {
                        try await SourceManager.shared.importRunner(from: url, with: runner.0)
                    } catch {
                        Logger.shared.error("Failed to install runner of \(runner.0). \(error)")
                    }
                }
            }
        }
    }

    enum BackUpError: Error {
        case FailedToImport, InvalidBackup, EmptyBackup, FileExists
    }
}
