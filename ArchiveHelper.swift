//
//  ArchiveHelper.swift
//  Suwatte
//
//  Created by Mantton on 2023-06-20.
//

import UIKit

protocol ArchiveController {
    func getThumbnailImage(for path: URL) throws -> UIImage
    func getItemCount(for path: URL) throws -> Int
    func getImagePaths(for path: URL) throws -> [String]
    func getImageData(for url: URL, at path: String) throws -> Data
}
final class ArchiveHelper {
    private let zipController = ZipController()
    private let rarController = RarController()
    func getThumbnail(for path: URL) throws -> UIImage {
        switch path.pathExtension {
            case "zip", "cbz":
                return try zipController.getThumbnailImage(for: path)
            case "rar", "cbr":
                return try rarController.getThumbnailImage(for: path)
            default: break
        }
        throw Errors.ArchiveNotFound
    }
    
    func getItemCount(for path: URL) throws -> Int {
        switch path.pathExtension {
            case "zip", "cbz":
                return try zipController.getItemCount(for: path)
            case "rar", "cbr":
                return try rarController.getItemCount(for: path)
            default: break
        }
        throw Errors.ArchiveNotFound
    }
    
    func getImagePaths(for path: URL) throws -> [String] {

        switch path.pathExtension {
        case "zip", "cbz":
            return try zipController.getImagePaths(for: path)
        case "rar", "cbr":
            return try rarController.getImagePaths(for: path)
        default: break
        }
        throw Errors.FailedToExtractItems
    }

    func getImageData(for url: URL, at path: String) throws -> Data {

        switch url.pathExtension {
        case "zip", "cbz":
            return try zipController.getImageData(for: url, at: path)
        case "rar", "cbr":
            return try rarController.getImageData(for: url, at: path)
        default: break
        }
        throw Errors.FailedToExtractItems
    }
    
}


extension ArchiveHelper {
    enum Errors : String {
        case ArchiveNotFound
        case FailedToExtractItems
    }
}


extension ArchiveHelper.Errors: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ArchiveNotFound:
            return NSLocalizedString(
                "Unable to locate the specified archive",
                comment: "Archive Not Found"
            )
        case .FailedToExtractItems:
            return NSLocalizedString("Failed to extract contents of archive", comment: "Failed to extract archive contents")
        }
    }
}