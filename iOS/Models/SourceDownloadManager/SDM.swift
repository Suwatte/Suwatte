//
//  SDM.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Combine
import Foundation

let SDM_FolderName = "ChapterDownloads"
final actor SourceDownloadManager {
    // Paths
    internal let directory = FileManager
        .default
        .documentDirectory
        .appendingPathComponent(SDM_FolderName, isDirectory: true)

    internal let tempDir = FileManager
        .default
        .documentDirectory
        .appendingPathComponent(SDM_FolderName, isDirectory: true)
        .appendingPathComponent("__temp__", isDirectory: true)

    internal let CONTEXT = "DownloadManager"

    // Core
    internal var queue: [SourceDownload] = []

    // State
    internal var isIdle = true
    internal var pausedTasks = Set<String>()
    internal var cancelledTasks = Set<String>()
    internal var archivesMarkedForDeletion = Set<String>()
    internal var foldersMarkedForDeletion = Set<String>()

    // Publishers
    @MainActor
    var activeDownload: CurrentValueSubject<(String, DownloadState)?, Never> = .init(nil)

    static let shared = SourceDownloadManager()
    init() {
        if !directory.exists { directory.createDirectory() }
        if !tempDir.exists { tempDir.createDirectory() }
    }
}

// Typealias
typealias SDM = SourceDownloadManager

// Enums
extension SDM {
    enum TaskCompletionState {
        case completed, failed, halted

        var DownloadState: DownloadStatus {
            switch self {
            case .completed: return .completed
            case .failed: return .failing
            case .halted: return .idle
            }
        }
    }

    enum DownloadState {
        case fetchingImages, downloading(progress: Double), finalizing
    }
}

// MARK: Public

extension SDM {
    func appDidStart() async {
        Logger.shared.log("Resource Initialized", CONTEXT)
        clearOldDirectory()
        await reattach()
        await clean()
        await fetchQueue()
        if !queue.isEmpty {
            ToastManager.shared.info("Downloads Restarted.")
        }
    }

    func isLocked() -> Bool {
        !isIdle
    }
}

// MARK: Observer

extension SDM {
    private func clearOldDirectory() {
        let directory = FileManager.default.applicationSupport.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }
}

typealias ChapterIdentifier = (source: String, content: String, chapter: String)

// MARK: Helpers

extension SDM {
    func fire() {
        guard isIdle, !queue.isEmpty else { return } // Start if the downloader is idle but the queue is not empty
        // Move to Next
        Task {
            await download()
        }
    }

    func setQueue(_ q: [SourceDownload]) {
        queue = q
        fire()
    }

    func parseID(_ id: String) -> ChapterIdentifier {
        let splitted = id.components(separatedBy: "||")
        return (splitted[0], splitted[1], splitted[2])
    }
}

// MARK: Publisher

extension SDM {
    func announce(_ id: String, state: DownloadState) {
        Task { @MainActor in
            activeDownload.send((id, state))
        }
    }

    func announce() {
        Task { @MainActor in
            activeDownload.send(nil)
        }
    }
}

extension SDM {
    func clean() async {
        // Delete Records
        await delete(ids: Array(cancelledTasks))

        // Delete Physical Locations
        for archive in archivesMarkedForDeletion {
            removeArchive(at: buildArchive(archive))
        }

        for id in foldersMarkedForDeletion {
            removeDirectory(at: folder(for: id))
        }

        // Update Indexes
        let ts = cancelledTasks
        Task {
            let unique = ts.compactMap { val in
                let ids = parseID(val)
                return ContentIdentifier(contentId: ids.content, sourceId: ids.source).id
            }
            .distinct()

            let actor = await RealmActor()
            await actor.updateDownloadIndex(for: unique)
        }

        // Consume States
        cancelledTasks.removeAll()
        archivesMarkedForDeletion.removeAll()
        foldersMarkedForDeletion.removeAll()
    }
}

// MARK: Chapter Data Fetcher

extension SDM {
    func getChapterData(for id: String) async throws -> StoredChapterData? {
        let download = await get(id)?.freeze()

        guard let download, download.status == .completed else { return nil }

        let data = StoredChapterData()
        data.chapter = download.chapter

        // Text
        if let text = download.text {
            data.text = text
            return data
        }

        // Archive
        if let archive = download.archive {
            let url = directory
                .appendingPathComponent("Archives", isDirectory: true)
                .appendingPathComponent(archive)

            // URL is pointing to a file, an archive
            let paths = try ArchiveHelper().getImagePaths(for: url)

            data.archiveURL = url
            data.archivePaths = paths
            return data
        }

        // Directory
        let url = folder(for: id)

        if url.hasDirectoryPath {
            let imageExtensions = ["jpg", "png", "gif", "jpeg", "bmp", "tiff", "heif", "heic"]
            let directoryContents = try FileManager
                .default
                .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let imageUrls = directoryContents
                .filter { imageExtensions.contains($0.pathExtension) }
                .sorted(by: \.fileName, descending: false)

            data.urls = imageUrls
            return data
        }

        Logger.shared.warn("Download record exists but archive & directory cases were not met", CONTEXT)
        return nil
    }
}
