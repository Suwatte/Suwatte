//
//  AH+Zip.swift
//  Suwatte
//
//  Created by Mantton on 2023-06-20.
//

import UIKit
import ZIPFoundation

extension ArchiveHelper {
    class ZipController: ArchiveController {
        func getImagePaths(for path: URL) throws -> [String] {
            let archive = getZIPArchive(for: path)

            guard let archive else {
                throw Errors.ArchiveNotFound
            }

            // Reference: https://medium.com/macoclock/how-to-implement-natural-sorting-on-the-alphanumeric-array-in-swift-5b8f64173725
            let files = archive
                .sorted(by: { $0.path.compare($1.path, options: .numeric) == .orderedAscending })
                .filter { $0.type == .file && isImagePath($0.path) }
                .map { $0.path }

            return files
        }

        func getItemCount(for path: URL) throws -> Int {
            let archive = getZIPArchive(for: path)

            guard let archive else {
                throw Errors.ArchiveNotFound
            }
            return archive
                .filter { $0.type == .file && isImagePath($0.path) }
                .count
        }

        func getThumbnailImage(for path: URL) throws -> UIImage {
            let archive = getZIPArchive(for: path)

            guard let archive else {
                throw Errors.ArchiveNotFound
            }

            let thumbnailPath = getThumbnail(for: archive)

            guard let thumbnailPath else {
                throw Errors.ArchiveNotFound
            }

            let imageData = try getImageData(for: archive.url, at: thumbnailPath)

            guard let image = UIImage(data: imageData) else {
                throw Errors.ArchiveNotFound
            }

            return image
        }

        func getZIPArchive(for path: URL) -> Archive? {
            guard let archive = Archive(url: path, accessMode: .read) else {
                return nil
            }

            return archive
        }

        func decodeImage(from url: URL, entry: Entry) -> UIImage? {
            guard let archive = Archive(url: url, accessMode: .read) else {
                return nil
            }
            var data = Data()

            _ = try? archive.extract(entry, consumer: { buff in
                data.append(buff)
            })

            return UIImage(data: data)
        }

        func getThumbnail(for archive: Archive) -> String? {
            let entry = archive
                .sorted(by: { $0.path < $1.path })
                .first(where: { $0.type == .file && isImagePath($0.path) })
            if let entry = entry {
                return entry.path
            }

            return nil
        }

        func getImageData(for url: URL, at path: String) throws -> Data {
            guard let archive = Archive(url: url, accessMode: .read), let file = archive[path] else {
                throw ArchiveHelper.Errors.ArchiveNotFound
            }
            try Task.checkCancellation()

            var out = Data()

            _ = try archive.extract(file) { data in
                try Task.checkCancellation()
                out.append(data)
            }

            return out
        }

        func getComicInfo(for url: URL) throws -> Data? {
            let archive = getZIPArchive(for: url)

            guard let archive else {
                throw Errors.ArchiveNotFound
            }

            let target = archive
                .first(where: { entry in
                    entry.type == .file && entry.path.lowercased().contains("comicinfo.xml")
                })

            guard let target else {
                return nil // Return nil if file does not have info.xml
            }

            var out = Data()

            _ = try archive.extract(target) { data in
                try Task.checkCancellation()
                out.append(data)
            }

            return out
        }
    }
}
