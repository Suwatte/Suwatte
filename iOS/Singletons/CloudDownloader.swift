//
//  CloudDownloader.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-28.
//

import Foundation

class CloudDownloader {
    private let metadataQuery = NSMetadataQuery()
    private var callback: ((Result<URL, Error>) -> Void)?

    func download(_ url: URL, _ callback: @escaping ((Result<URL, Error>) -> Void)) {
        metadataQuery.stop()
        self.callback = callback
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
            let baseFileName = url.lastPathComponent
            let predicate = NSPredicate(format: "%K.lastPathComponent == %@", NSMetadataItemURLKey, baseFileName)
            metadataQuery.predicate = predicate
            metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            let queue = OperationQueue()
            queue.qualityOfService = .userInteractive
            queue.maxConcurrentOperationCount = 1
            metadataQuery.operationQueue = queue
            NotificationCenter.default.addObserver(self, selector: #selector(updateReceived(_:)), name: .NSMetadataQueryDidUpdate, object: metadataQuery)
            NotificationCenter.default.addObserver(self, selector: #selector(updateReceived(_:)), name: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
            
            
            metadataQuery.start()
            
        } catch {
            callback(.failure(error))
        }
    }

    @objc private func updateReceived(_: Notification) {
        checkDownloadStatus()
    }
    
    func cancel() {
        metadataQuery.stop()
    }

    private func checkDownloadStatus() {
        let defaultError = DSK.Errors.NamedError(name: "CloudDownloader", message: "Failed to download requested file")
        guard let results = metadataQuery.results as? [NSMetadataItem], let item = results.first else {
            DispatchQueue.main.async { [weak self] in
                self?.callback?(.failure(defaultError))
            }
            return
        }
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
            DispatchQueue.main.async { [weak self] in
                self?.callback?(.failure(defaultError))
            }
            return
        }
        do {
            let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if values.ubiquitousItemDownloadingStatus == .current {
                DispatchQueue.main.async { [weak self] in
                    self?.callback?(.success(url))
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.callback?(.failure(error))
            }
        }
    }
}

