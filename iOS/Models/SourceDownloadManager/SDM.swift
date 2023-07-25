//
//  SDM.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation
import Combine

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
    internal var isIdle = false
    internal var pausedTasks = Set<String>()
    internal var cancelledTasks = Set<String>()
    
    // Publishers
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
    func appDidStart() {
        Logger.shared.log("Resource Initialized", CONTEXT)
        clearOldDirectory()
        fetchQueue()
        clean()
        print(directory.relativePath)
    }
}
// MARK: Observer
extension SDM {
    
    private func clearOldDirectory() {
        let directory = FileManager.default.applicationSupport.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }
}


// MARK: Helpers
extension SDM {
    internal func fire() {
        guard !isIdle, !queue.isEmpty else { return } // Start if the downloader is idle but the queue is not empty
        // Move to Next
        Task {
            await download()
        }
    }
    
    internal func setQueue(_ q: [SourceDownload]) {
        queue = q
        fire()
    }
    
    internal func parseID(_ id: String) -> ChapterIndentifier {
        let splitted = id.components(separatedBy: "||")
        return (splitted[0], splitted[1], splitted[2])
    }
}


// MARK: Publisher
extension SDM {
    internal func announce(_ id: String, state: DownloadState) {
        Task { @MainActor in
            await activeDownload.send((id, state))
        }
    }
    
    internal func announce() {
        Task { @MainActor in
            await activeDownload.send(nil)
        }
    }
}

extension SDM {
    func clean() {
        
    }
}



// MARK: Chapter Data Fetcher
extension SDM {
    func getChapterData(for id: String) throws -> StoredChapterData? {
        let download = get(id)?.freeze()
        
        guard let download, download.status == .completed else { return nil }
        
        let data = StoredChapterData()
        data.chapter = download.chapter
        
        // Text
        if let text = download.text {
            data.text = text
            return data
        }
        
        // File / Directory
        guard let path = download.path else {
            Logger.shared.warn("Requested a valid download but the path has not been set (\(id)", CONTEXT)
            return nil
        }
        
        guard let url = URL(string: path), url.isFileURL, url.exists else {
            Logger.shared.warn("Requested a valid download but the path is not a valid url (\(id)", CONTEXT)
            // Delete
            return nil
        }
        
        if url.hasDirectoryPath {
            let imageExtensions = ["jpg", "png", "gif", "jpeg", "bmp", "tiff", "heif", "heic"]

            let imageUrls = try FileManager
                .default
                .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { imageExtensions.contains($0.pathExtension) }
                .sorted(by: \.fileName, descending: false)
            
            data.urls = imageUrls
            return data
        }
        
        // URL is pointing to a file, an archive
        let paths = try ArchiveHelper().getImagePaths(for: url)
        data.archiveURL = url
        data.archivePaths = paths
        return data
    }
}
