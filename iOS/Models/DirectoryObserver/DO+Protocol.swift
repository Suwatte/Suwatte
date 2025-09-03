//
//  DO+Protocol.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import Foundation
import NukeUI
import QuickLook
import UIKit

struct File: Identifiable, Hashable {
    let url: URL
    let isOnDevice: Bool
    let id: String

    // Properties
    let name: String
    let created: Date
    let addedToDirectory: Date
    let size: Int64
    var pageCount: Int?
    var metaData: ComicNameParser.Name?

    func sizeToString() -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct Folder: Hashable {
    let url: URL
    var files: [File] = []
    var folders: [SubFolder] = []

    struct SubFolder: Identifiable, Hashable {
        let url: URL
        let id: String
        let name: String
    }
}

enum DirectorySortOption: Int, CaseIterable, UserDefaultsSerializable {
    case creationDate, size, title, dateAdded

    var description: String {
        switch self {
        case .title:
            return "Title"
        case .size:
            return "File Size"
        case .creationDate:
            return "Creation Date"
        case .dateAdded:
            return "Date Added"
        }
    }
}

protocol DirectoryObserver {
    func observe(_ callback: @escaping ((Folder) -> Void))
    func stop()

    var path: URL { get }
    var extensions: [String] { get }
}

extension File {
    func imageRequest(_ size: CGSize) -> ImageRequest {
        ImageRequest(id: id) {
            guard let data = try await getThumbnail(size: size) else {
                throw DSK.Errors.NamedError(name: "DirectoryViewer", message: "Unable to convert image to data representation")
            }
            return data
        }
    }

    private func getThumbnail(size: CGSize) async throws -> Data? {
        return try await generateThumb(for: url, size: size).pngData()
    }

    private func generateThumb(for path: URL, size: CGSize) async throws -> UIImage {
        let request = await QLThumbnailGenerator.Request(fileAt: path, size: size, scale: UIScreen.main.scale, representationTypes: .thumbnail)
        let thumbnailGenerator = QLThumbnailGenerator.shared
        let result = try await thumbnailGenerator.generateBestRepresentation(for: request)
        return result.uiImage
    }
}

extension URL {
    func convertToSTTFile() throws -> File {
        let resources = try? resourceValues(forKeys: [.fileContentIdentifierKey, .fileSizeKey, .addedToDirectoryDateKey, .creationDateKey, .contentModificationDateKey, .ubiquitousItemDownloadingStatusKey])
        var isOnDevice = true

        if let status = resources?.ubiquitousItemDownloadingStatus {
            isOnDevice = status == .current
        } else {
            isOnDevice = exists
        }

        let fileSize = resources?.fileSize.flatMap(Int64.init) ?? .zero
        let creationDate = resources?.creationDate ?? .now
        let modificationDate = resources?.contentModificationDate ?? .now
        let addedDirectoryDate = resources?.addedToDirectoryDate ?? .now
        let fileId = STTHelpers.generateFileIdentifier(size: fileSize, created: creationDate, modified: modificationDate)
        let metaData = ComicNameParser().getNameProperties(fileName)
        return .init(url: self, isOnDevice: isOnDevice, id: fileId, name: fileName, created: creationDate, addedToDirectory: addedDirectoryDate, size: fileSize, pageCount: nil, metaData: metaData)
    }
}
