//
//  BackupManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation

class BackupManager: ObservableObject {
    private var observer: DispatchSourceFileSystemObject?
    static let shared = BackupManager()
    let directory = FileManager.default.documentDirectory.appendingPathComponent("Backups", isDirectory: true)
    @Published var urls: [URL]

    init() {
        if !directory.exists {
            directory.createDirectory()
        }
        urls = directory.contents.sorted(by: \.lastModified, descending: true)
    }

    func refresh() {
        let urls = directory
            .contents
            .sorted(by: \.lastModified, descending: true)
            .filter { $0.pathExtension == "json" }
        Task { @MainActor in
            self.urls = urls
        }
    }

    func save(name: String? = nil) async throws {
        let backup = await create()
        let json = try backup.encoded()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy HH:mm:ss"
        let name = name ?? .random(length: 5)
        let path = directory.appendingPathComponent("STT_BACKUP_\(name)_\(dateFormatter.string(from: backup.date)).json")
        try json.write(to: path)
        refresh()
    }

    func create() async -> Backup {
        let actor = await RealmActor.shared()
        return await actor.createBackup()
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

    private func restoreDB(backup: Backup) async throws {
        let actor = await RealmActor.shared()
        try await actor.restoreBackup(backup: backup)
    }

    func restoreProgressMarkers(from url: URL) async throws -> Int {
        var backup: OldBackup?

        do {
            backup = try OldBackup.load(from: url)
        } catch {
            Logger.shared.error(error, "BackupManager")
            throw error
        }

        guard let backup = backup, let version = backup.schemaVersion, version < 16 else {
            throw BackUpError.InvalidBackup
        }

        guard let progressMarkers = backup.progressMarkers else {
            throw BackUpError.EmptyBackup
        }

        // Install
        let actor = await RealmActor.shared()
        return try await actor.restoreOldProgressMarkers(progressMarkers: progressMarkers)
    }

    func restore(from url: URL) async throws {
        // Load
        var backup: Backup?

        do {
            backup = try Backup.load(from: url)
        } catch {
            Logger.shared.error(error, "BackupManager")
            throw error
        }

        guard let backup = backup else {
            throw BackUpError.InvalidBackup
        }

        let runners = backup.runners?.map { ($0.id, $0.listURL) } ?? []

        // Install
        try await restoreDB(backup: backup)

        guard !runners.isEmpty, backup.schemaVersion >= 14 else { return }

        await withTaskGroup(of: Void.self) { group in
            for runner in runners {
                guard let url = URL(string: runner.1) else { return }
                group.addTask {
                    do {
                        try await DSK.shared.importRunner(from: url, with: runner.0)
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
