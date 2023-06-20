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
        path = url
    }

    func observe(_ callback: @escaping ((Folder) -> Void)) {
        self.callback = callback
        setup()
        metadataQuery.start()
    }

    func stopObserving() {
        metadataQuery.disableUpdates()
        metadataQuery.stop()
    }

    deinit {
        stopObserving()
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
        handleQueryDidUpdate(notification as Notification)
        parseList()
    }

    @objc func queryDidFinishGathering(notification _: NSNotification) {
        print("Stopped Gathering")
        metadataQuery.enableUpdates()
        parseList()
    }

    func parseList() {
        metadataQuery.disableUpdates()
        defer {
            metadataQuery.enableUpdates()
        }
        guard let items = metadataQuery.results as? [NSMetadataItem] else {
            return
        }
        print("Update Recieved, Result Count", items.count)

        guard let items = metadataQuery.results as? [NSMetadataItem] else {
            return
        }

//        var rootFolder = Folder(url: path)
        for item in items {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            guard url.deletingLastPathComponent() == path else { continue }

            if url.hasDirectoryPath { // Folder
                print("Folder:", url.lastPathComponent)
                continue
            }

            guard extensions.contains(url.pathExtension) else { continue }

            print("File  :", url.lastPathComponent)
        }

        callback?(.init(url: path))
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

    @objc private func updateReceived(_: Notification) {
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
