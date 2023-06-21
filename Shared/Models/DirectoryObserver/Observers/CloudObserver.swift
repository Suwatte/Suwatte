//
//  CloudObserver.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import Foundation

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
        metadataQuery.operationQueue = .main
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
        print("Started Gathering")
        metadataQuery.disableUpdates()
    }
    
    @objc func queryDidUpdate(notification: NSNotification) {
        print("Update Recieved")
        metadataQuery.disableUpdates()
//        handleQueryDidUpdate(notification as Notification)
        parseList()
    }
    
    @objc func queryDidFinishGathering(notification _: NSNotification) {
        print("Stopped Gathering")
        metadataQuery.enableUpdates()
        parseList()
    }
    
    func parseList() {
        metadataQuery.disableUpdates()
        guard let items = metadataQuery.results as? [NSMetadataItem] else {
            metadataQuery.enableUpdates()
            return
        }
        print("Update Recieved, Result Count", items.count)
        
        guard let items = metadataQuery.results as? [NSMetadataItem] else {
            metadataQuery.enableUpdates()
            return
        }
        
        var rootFolder = Folder(url: path)
        for item in items {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue } // Get URL
            guard url.deletingLastPathComponent() == path else { continue } // Is File in this directory
            
            // Folder
            if url.hasDirectoryPath {
                let created = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? .now
                let folder: Folder.SubFolder = .init(url: url, id: generateFolderIdentifier(created: created))
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
            let id = generateFileIdentifier(size: fileSize, created: creationDate, modified: contentChangeDate)
            let file = File(url: url, isOnDevice: isDownloaded, id: id, name: url.fileName, created: creationDate, size: fileSize)
            rootFolder.files.append(file)
        }
        
        callback?(rootFolder)
        metadataQuery.enableUpdates()
    }
    
    // Handle query's update notification
    private func handleQueryDidUpdate(_ notification: Notification) {
        print("Query Did Update")
        guard let query = notification.object as? NSMetadataQuery else { return }
        
        query.disableUpdates()
        
        // Process the query update
        let addedItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
        let changedItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] ?? []
        let removedItems = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] ?? []
        
        // Handle added items
        for item in addedItems {
            if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                // Handle the added item path
                print("Added item path: \(path)")
            }
        }
        
        // Handle changed items
        for item in changedItems {
            if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                // Handle the changed item path
                print("Changed item path: \(path)")
            }
        }
        
        // Handle removed items
        for item in removedItems {
            if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                // Handle the removed item path
                print("Removed item path: \(path)")
            }
        }
        
        query.enableUpdates()
    }
    
}
