//
//  CloudDownloader.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-28.
//

import Foundation

class DirectoryObserver {
    private let metadataQuery = NSMetadataQuery()
    private let extensions: [String]
    private let path: URL
    private var callback: ((Folder) -> Void)?
    
    
    
    init(extensions: [String], url: URL) {
        self.extensions = extensions
        self.path = url
    }
    
    func observe( _ callback : @escaping ((Folder) -> Void)) {
        self.callback = callback
        self.setup()
        metadataQuery.start()
    }
    
    func stopObserving() {
        metadataQuery.disableUpdates()
        metadataQuery.stop()
        path.stopAccessingSecurityScopedResource()
    }
    deinit {
        stopObserving()
    }
    
    
    
    private func setup() {
        
        metadataQuery.notificationBatchingInterval = 1
        metadataQuery.operationQueue = .main
        metadataQuery.searchScopes = [ NSMetadataQueryUbiquitousDocumentsScope]
        let predicateString = "(%K BEGINSWITH %@) AND NOT (%K CONTAINS %@)"
        let parentPath = path.path.appending("/") // Make sure path ends with a slash
        print(parentPath)
        let predicate = NSPredicate(format: predicateString, NSMetadataItemPathKey, parentPath, NSMetadataItemPathKey, parentPath.appending("/"))
        metadataQuery.predicate = predicate
        metadataQuery.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true)]
        
        NotificationCenter.default.addObserver(self, selector: #selector(queryDidStartGathering(notification:)), name: NSNotification.Name.NSMetadataQueryDidStartGathering, object: metadataQuery)
        
        // This notification is posted during an update. However, it is not posted upon completion of an update.
        NotificationCenter.default.addObserver(self, selector: #selector(queryDidUpdate(notification:)), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)
        
        // This notification is posted after the initial query gathering is complete.
        NotificationCenter.default.addObserver(self, selector: #selector(queryDidFinishGathering(notification:)), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)
        
    }
    
    
    @objc func queryDidStartGathering(notification: NSNotification) {
        print("Started Gathering")
        metadataQuery.disableUpdates()
    }
    
    @objc func queryDidUpdate(notification: NSNotification) {
        print("Update Recieved")
        metadataQuery.disableUpdates()
        parseList()
    }
    
    @objc func queryDidFinishGathering(notification: NSNotification) {
        print("Stopped Gathering")
        metadataQuery.enableUpdates()
        parseList()
    }
    
    
    func parseList(){
        metadataQuery.disableUpdates()
        defer {
            metadataQuery.enableUpdates()
        }
        guard let items = metadataQuery.results as? [NSMetadataItem]  else {
            return
        }
        print("Update Recieved, Result Count", items.count)
        
        guard let items = metadataQuery.results as? [NSMetadataItem] else {
            return
        }
        
        var rootFolder = Folder(url: path)
        for item in items {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            guard url.deletingLastPathComponent() == path else {continue }
            
            if url.hasDirectoryPath { // Folder
                print("Folder", url.lastPathComponent)
                continue
            }
            
            guard extensions.contains(url.pathExtension) else { continue }
            
            
            print("File", url.lastPathComponent)
        }
        
        callback?(rootFolder)
    }
}


class CloudDownloader {
    private let metadataQuery = NSMetadataQuery()
    var downloadCompletion: ((Result<URL, Error>) -> Void)?
    
    
    func download(_ url: URL) {
        setupMetadataQuery()
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
            let baseFileName = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .punctuationCharacters)
            let predicate = NSPredicate(format: "(%K.pathExtension == %@ OR %K.pathExtension == %@) AND %K.lastPathComponent == %@", NSMetadataItemURLKey, "icloud", NSMetadataItemURLKey, "json", NSMetadataItemURLKey, baseFileName)
            metadataQuery.predicate = predicate
            
        } catch {
            downloadCompletion?(.failure(error))
        }
    }
    
    private func setupMetadataQuery() {
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.operationQueue = .main
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateReceived(_:)), name: .NSMetadataQueryDidUpdate, object: metadataQuery)
        metadataQuery.start()
    }
    
    @objc private func updateReceived(_ notification: Notification) {
        checkDownloadStatus()
    }
    
    
    private func checkDownloadStatus() {
        guard let results = metadataQuery.results as? [NSMetadataItem], let item = results.first else { return }
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { return }
        do {
            let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if values.ubiquitousItemDownloadingStatus == .current {
                downloadCompletion?(.success(url))
            }
        } catch {
            downloadCompletion?(.failure(error))
        }
    }
}


extension DirectoryObserver {
    struct File {
        let url: URL
        // Any other properties you need
    }
    
    struct Folder {
        let url: URL
        var files: [File] = []
        var folders: [Folder] = []
    }
    
}
