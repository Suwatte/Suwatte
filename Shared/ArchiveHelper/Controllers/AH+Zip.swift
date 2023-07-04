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
            
            let files = archive
                .sorted(by: { $0.path < $1.path })
                .filter { $0.type == .file && ($0.path.hasSuffix("png") || $0.path.hasSuffix("jpg")) }
                .map { $0.path }

            return files
        }
        
        func getItemCount(for path: URL) throws -> Int {
            let archive = getZIPArchive(for: path)
            
            guard let archive else {
                throw Errors.ArchiveNotFound
            }
            
            return archive.reversed().count
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
                .first(where: { $0.type == .file && ($0.path.hasSuffix("png") || $0.path.hasSuffix("jpg")) })
            if let entry = entry {
                return entry.path
            }

            return nil
        }
        
        func getImageData(for url: URL, at path: String) throws -> Data {
            guard let archive = Archive(url: url, accessMode: .read), let file = archive[path] else {
                throw ArchiveHelper.Errors.ArchiveNotFound
            }

            var out = Data()

            _ = try archive.extract(file) { data in

                out.append(data)
            }

            return out
        }
    }
}