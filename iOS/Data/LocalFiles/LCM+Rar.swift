//
//  LCM+Rar.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-07.
//

import Foundation
import UIKit
import Unrar

extension LocalContentManager {
    class RarClient {
        func getRARArchive(for path: URL) -> Archive? {
            guard let archive = try? Archive(fileURL: path) else {
                return nil
            }

            return archive
        }

        func decodeImage(from url: URL, entry: Entry) -> UIImage? {
            guard let archive = try? Archive(fileURL: url) else {
                return nil
            }
            let data = try? archive.extract(entry)

            if let data = data {
                return UIImage(data: data)
            }

            return nil
        }

        func getThumbnail(for archive: Archive) -> String? {
            let entries = try? archive.entries()

            guard let entries = entries else {
                return nil
            }
            let entry = entries
                .sorted(by: { $0.fileName < $1.fileName })
                .first(where: { !$0.directory && ($0.fileName.hasSuffix("png") || $0.fileName.hasSuffix("jpg")) })
            if let entry = entry {
                return entry.fileName
            }

            return nil
        }

        func getArchiveEntryList(for url: URL) -> [String]? {
            guard let archive = try? Archive(fileURL: url) else {
                return nil
            }

            let files = try? archive
                .entries()
                .sorted(by: { $0.fileName < $1.fileName })
                .filter { !$0.directory && ($0.fileName.hasSuffix("png") || $0.fileName.hasSuffix("jpg")) || $0.fileName.hasSuffix("jpeg") }
                .map { $0.fileName }
            return files
        }

        func getImageData(for url: URL, with path: String) throws -> Data {

            let archive = try Archive(fileURL: url)

            let entries = try archive.entries()

            let entry = entries.first(where: {
                $0.fileName == path
            })

            if entry == nil {
                throw Errors.DNE
            }
            return try archive.extract(entry!)
        }
    }
}
