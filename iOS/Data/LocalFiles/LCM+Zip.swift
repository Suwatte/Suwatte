//
//  LCM+Zip.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-07.
//

import Foundation
import UIKit
import ZIPFoundation

extension LocalContentManager {
    class ZipClient {
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

        func getArchiveEntryList(for url: URL) -> [String]? {
            guard let archive = Archive(url: url, accessMode: .read) else {
                return nil
            }
            let files = archive
                .sorted(by: { $0.path < $1.path })
                .filter { $0.type == .file && ($0.path.hasSuffix("png") || $0.path.hasSuffix("jpg")) }
                .map { $0.path }

            return files
        }

        func getImageData(for url: URL, with path: String) throws -> Data {
            guard let archive = Archive(url: url, accessMode: .read), let file = archive.first(where: { $0.path == path }) else {
                throw Errors.DNE
            }

            var out = Data()

            _ = try archive.extract(file) { data in

                out.append(data)
            }

            return out
        }
    }
}
