//
//  CloudObserver.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import Foundation
import Fuzi

class CloudObserver: DirectoryObserver {
    private let metadataQuery = NSMetadataQuery()
    internal let extensions: [String]
    internal let path: URL
    private var callback: ((Folder) -> Void)?

    init(extensions: [String], url: URL) {
        self.extensions = extensions
        path = url
    }

    func observe(_ callback: @escaping ((Folder) -> Void)) {
        self.callback = callback
        setup()
        metadataQuery.start()
    }

    func stop() {
        metadataQuery.disableUpdates()
        metadataQuery.stop()
    }

    deinit {
        stop()
    }

    private func setup() {
        metadataQuery.notificationBatchingInterval = 1
        let queue = OperationQueue()
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1

        metadataQuery.operationQueue = queue
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        let escapedPath = NSRegularExpression.escapedPattern(for: path.path)
        let predicateString = "%K MATCHES '^" + escapedPath + "/[^/]*$'"
        metadataQuery.predicate = NSPredicate(format: predicateString, NSMetadataItemPathKey)
        metadataQuery.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true)]

        NotificationCenter.default.addObserver(self, selector: #selector(queryDidStartGathering(notification:)), name: NSNotification.Name.NSMetadataQueryDidStartGathering, object: metadataQuery)

        // This notification is posted during an update. However, it is not posted upon completion of an update.
        NotificationCenter.default.addObserver(self, selector: #selector(queryDidUpdate(notification:)), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)

        // This notification is posted after the initial query gathering is complete.
        NotificationCenter.default.addObserver(self, selector: #selector(queryDidFinishGathering(notification:)), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)
    }

    @objc func queryDidStartGathering(notification _: NSNotification) {
        metadataQuery.disableUpdates()
    }

    @objc func queryDidUpdate(notification _: NSNotification) {
        parseList()
    }

    @objc func queryDidFinishGathering(notification _: NSNotification) {
        parseList()
    }

    func parseList() {
        metadataQuery.disableUpdates()
        guard let items = metadataQuery.results as? [NSMetadataItem] else {
            metadataQuery.enableUpdates()
            return
        }
        let nameParser = ComicNameParser()
        var rootFolder = Folder(url: path)
        var files: [File] = []
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

            var pageCount: Int? = nil
            if isDownloaded {
                pageCount = try? ArchiveHelper().getItemCount(for: url)
            }

            let name = nameParser.getNameProperties(url.fileName)
            let file = File(url: url, isOnDevice: isDownloaded, id: id, name: url.fileName, created: creationDate, addedToDirectory: addedToDirectoryDate, size: fileSize, pageCount: pageCount, metaData: name)
            files.append(file)
        }

        STTHelpers.sortFiles(files: &files)

        rootFolder.files = files
        DispatchQueue.main.async { [weak self] in
            self?.callback?(rootFolder)
        }
        metadataQuery.enableUpdates()
    }
}


extension File {
    var cName: String {
        metaData?.formattedName ?? name
    }
}
extension STTHelpers {
    static func sortFiles(files: inout [File]) {
        let sortKey = Preferences.standard.directoryViewSortKey
        let orderKey = Preferences.standard.directoryViewOrderKey

        switch sortKey {
        case .creationDate:
            files = files.sorted(by: \.created, descending: orderKey)
        case .size:
            files = files.sorted(by: \.size, descending: orderKey)
        case .title:
            files = files.sorted(by: \.cName, descending: orderKey)
        case .dateAdded:
            files = files.sorted(by: \.addedToDirectory, descending: orderKey)
        case .lastRead:
            files = files.sorted(by: \.dateRead, descending: orderKey)
        }
    }

    static func indexComicInfo(for url: URL) {
        do {
            let data = try ArchiveHelper().getComicInfo(for: url)
            guard let data else { return }
            let document = try XMLDocument(data: data)
            let info = ComicInfo.fromXML(document)

        } catch {
            Logger.shared.error(error, "CloudObserver")
        }
    }
}
