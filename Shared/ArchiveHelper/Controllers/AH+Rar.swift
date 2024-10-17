//
//  AH+Rar.swift
//  Suwatte
//
//  Created by Mantton on 2023-06-20.
//

import UIKit
import Unrar

extension ArchiveHelper {
    class RarController: ArchiveController {
        func getImagePaths(for path: URL) throws -> [String] {
            let archive = getRARArchive(for: path)

            guard let archive else {
                throw Errors.ArchiveNotFound
            }

            let files = try archive
                .entries()
                .sorted(by: { $0.fileName.compare($1.fileName, options: .numeric) == .orderedAscending })
                .filter { !$0.directory && isImagePath($0.fileName) }
                .map { $0.fileName }

            return files
        }

        func getImageData(for url: URL, at path: String) throws -> Data {
            let archive = try Archive(fileURL: url)

            let entries = try archive.entries()

            let entry = entries.first(where: {
                $0.fileName == path
            })

            guard let entry else {
                throw ArchiveHelper.Errors.ArchiveNotFound
            }

            var out = Data()

            try archive.extract(entry, handler: { data, progress in
                if Task.isCancelled {
                    progress.cancel()
                } else {
                    out.append(data)
                }
            })
            return out
        }

        func getItemCount(for path: URL) throws -> Int {
            let archive = getRARArchive(for: path)

            guard let archive else {
                throw Errors.ArchiveNotFound
            }
            return try archive
                .entries()
                .filter { !$0.directory && isImagePath($0.fileName) }
                .count
        }

        func getThumbnailImage(for path: URL) throws -> UIImage {
            let archive = getRARArchive(for: path)

            guard let archive else {
                throw Errors.ArchiveNotFound
            }

            let thumbnailPath = getThumbnail(for: archive)

            guard let thumbnailPath else {
                throw Errors.ArchiveNotFound
            }

            let imageData = try getImageData(for: archive.fileURL, at: thumbnailPath)

            guard let image = UIImage(data: imageData) else {
                throw Errors.ArchiveNotFound
            }

            return image
        }

        func getRARArchive(for path: URL) -> Archive? {
            guard let archive = try? Archive(fileURL: path) else {
                return nil
            }

            return archive
        }

        func getThumbnail(for archive: Archive) -> String? {
            let entries = try? archive.entries()

            guard let entries = entries else {
                return nil
            }
            let entry = entries
                .sorted(by: { $0.fileName < $1.fileName })
                .first(where: { !$0.directory && isImagePath($0.fileName) })
            if let entry = entry {
                return entry.fileName
            }

            return nil
        }

        func getComicInfo(for url: URL) throws -> Data? {
            let archive = getRARArchive(for: url)

            guard let archive else {
                throw Errors.ArchiveNotFound
            }

            let target = try archive
                .entries()
                .first(where: { !$0.directory && $0.fileName.lowercased().contains("comicinfo.xml") })

            guard let target else { return nil }

            return try archive.extract(target)
        }
    }
}
