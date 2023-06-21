//
//  CloudDownloader.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-28.
//

import Foundation

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

