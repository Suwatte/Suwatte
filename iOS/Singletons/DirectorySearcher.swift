//
//  DirectorySearcher.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-23.
//

import Foundation

final class DirectorySearcher {
    var path: URL
    var extensions: [String]
    private var metadataQuery: NSMetadataQuery?
    private var callback: ((Folder) -> Void)?
    init(path: URL, extensions: [String]) {
        self.path = path
        self.extensions = extensions
    }

    var isCloudEnabled: Bool {
        CloudDataManager.shared.isCloudEnabled
    }

    func search(query: String, _ callback: @escaping (Folder) -> Void) {
        self.callback = callback
        if isCloudEnabled {
            searchCloud(query: query)
        } else {
            Task.detached { [weak self] in
                self?.searchLocally(query: query)
            }
        }
    }

    // Reference: https://developer.apple.com/documentation/foundation/filemanager/2765464-enumerator#discussion
    private func searchLocally(query: String) {
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey])
        let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)!
        var rootFolder = Folder(url: path)

        for case let url as URL in enumerator {
            guard let resourceValues = try? url.resourceValues(forKeys: resourceKeys),
                  let isDirectory = resourceValues.isDirectory,
                  let name = resourceValues.name
            else {
                continue
            }

            if name.lowercased().contains(query.lowercased()) { // Valid Result Append
                // Folder
                if isDirectory {
                    let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .now
                    let name = url.lastPathComponent
                    let folder: Folder.SubFolder = .init(url: url, id: STTHelpers.generateFolderIdentifier(created: created, name: name), name: name)
                    rootFolder.folders.append(folder)
                    continue
                }

                // File
                guard extensions.contains(url.pathExtension) else { continue } // File Type Guard
                let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey, .addedToDirectoryDateKey])

                // Generate Unique Identifier
                let fileSize = resourceValues?.fileSize.flatMap(Int64.init) ?? .zero
                let creationDate = resourceValues?.creationDate ?? .now
                let contentChangeDate = resourceValues?.contentModificationDate ?? .now
                let addedToDirectory = resourceValues?.addedToDirectoryDate ?? .now
                let id = STTHelpers.generateFileIdentifier(size: fileSize, created: creationDate, modified: contentChangeDate)

                let pageCount = try? ArchiveHelper().getItemCount(for: url)
                let file = File(url: url, isOnDevice: true, id: id, name: url.fileName, created: creationDate, addedToDirectory: addedToDirectory, size: fileSize, pageCount: pageCount)
                rootFolder.files.append(file)
            }
        }
        DispatchQueue.main.async { @MainActor [weak self] in
            self?.callback?(rootFolder)
        }
    }

    private func searchCloud(query: String) {
        self.metadataQuery?.disableUpdates()
        self.metadataQuery?.stop()
        self.metadataQuery = nil
        self.metadataQuery = NSMetadataQuery()

        guard let metadataQuery else {
            return
        }

        metadataQuery.notificationBatchingInterval = 1
        let queue = OperationQueue()
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
        metadataQuery.operationQueue = queue
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        let predicate = NSPredicate(format: "(%K.lastPathComponent CONTAINS[cd] %@) AND (%K BEGINSWITH %@)",
                                    argumentArray: [NSMetadataItemURLKey, query, NSMetadataItemPathKey, path.path])
        metadataQuery.predicate = predicate
        metadataQuery.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true)]

        NotificationCenter.default.addObserver(self, selector: #selector(queryDidStartGathering(notification:)), name: NSNotification.Name.NSMetadataQueryDidStartGathering, object: metadataQuery)

        NotificationCenter.default.addObserver(self, selector: #selector(queryDidFinishGathering(notification:)), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)
        metadataQuery.start()
    }

    @objc private func queryDidStartGathering(notification _: NSNotification) {
        metadataQuery?.disableUpdates()
    }

    @objc private func queryDidFinishGathering(notification _: NSNotification) {
        parseList()
    }

    private func parseList() {
        guard let items = metadataQuery?.results as? [NSMetadataItem] else {
            return
        }

        var rootFolder = Folder(url: path)
        for item in items {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue } // Get URL
            guard url.deletingLastPathComponent() == path else { continue } // Is File in this directory

            // Folder
            if url.hasDirectoryPath {
                let created = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? .now
                let name = url.lastPathComponent
                let folder: Folder.SubFolder = .init(url: url, id: STTHelpers.generateFolderIdentifier(created: created, name: name), name: name)
                rootFolder.folders.append(folder)
                continue
            }

            // File
            guard extensions.contains(url.pathExtension) else { continue } // File Type Guard
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String ?? ""
            let isDownloaded = status == NSMetadataUbiquitousItemDownloadingStatusCurrent

            // Generate Unique Identifier
            let fileSize = (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber).flatMap(Int64.init) ?? .zero
            let creationDate = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? .now
            let contentChangeDate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date ?? .now

            let addedToDirectoryDate = (try? url.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate) ?? .now

            let id = STTHelpers.generateFileIdentifier(size: fileSize, created: creationDate, modified: contentChangeDate)

            var pageCount: Int?
            if isDownloaded {
                pageCount = try? ArchiveHelper().getItemCount(for: url)
            }
            let file = File(url: url, isOnDevice: isDownloaded, id: id, name: url.fileName, created: creationDate, addedToDirectory: addedToDirectoryDate, size: fileSize, pageCount: pageCount)
            rootFolder.files.append(file)
        }

        DispatchQueue.main.async { [weak self] in
            self?.callback?(rootFolder)
        }
    }
}
