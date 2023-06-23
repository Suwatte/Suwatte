//
//  LocalContentManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-07.
//

import Alamofire
import Foundation
import Nuke
import UIKit

final class LocalContentManager: ObservableObject {
    @Published var isSelecting = false
    @Published var idHash: [Int64: Book] = [:]

    static var shared = LocalContentManager()
    let directory = CloudDataManager
        .shared
        .getDocumentDiretoryURL()
        .appendingPathComponent("Library")
    internal let zipClient = ZipClient()
    internal let rarClient = RarClient()
    @Published var downloads: [DownloadObject] = []
    private var observer: DirectoryObserver?

    init() {
        directory.createDirectory()
    }

    func observe() {
        observer?.stop()
        let cloudEnabled = CloudDataManager.shared.isCloudEnabled
        observer = CloudObserver(extensions: ["cbr"], url: directory)
        guard let observer else { return }
        observer.observe { folder in
            print("\nRecieved Callback")
            print("Folders: ")
            folder.folders.forEach { f in
                print(f.url.lastPathComponent)
            }
            
            print("\nFiles: ")
            folder.files.forEach { f in
                print(f.url.lastPathComponent)
            }
        }
    }

    func stopObserving() {
        observer?.stop()
        observer = nil
    }

    enum Errors: Error {
        case FileExists
        case DNE
        case InvalidType
        case FailedToExtractArchive
        case BookGenerationFailed
    }

    func hasFile(fileName: String) -> Bool {
        let path = directory.appendingPathComponent(fileName)
        return path.exists
    }

    func getBook(withId id: Int64) -> Book? {
        idHash[id]
    }

    func importFile(at url: URL) throws {
        let targetLocation = directory.appendingPathComponent(url.lastPathComponent)
        if targetLocation.exists {
            Logger.shared.error("[Local CM] File Exists")
            throw Errors.FileExists
        }
        try FileManager.default.copyItem(at: url, to: targetLocation)
    }

    func generateBook(at path: URL) -> Book? {
        if path.hasDirectoryPath {
            return nil
        }
        let type = path.pathExtension
        if !["cbz", "cbr"].contains(type) {
            return nil
        }
        var title = String(path.lastPathComponent.split(separator: ".").first!)
        let resources = try? path.resourceValues(forKeys: [.fileResourceIdentifierKey, .fileContentIdentifierKey, .fileSizeKey, .creationDateKey, .addedToDirectoryDateKey])
        guard let fileId = resources?.fileContentIdentifier else {
            return nil
        }
        var fileSize: Int64?
        if let size = resources?.fileSize {
            fileSize = Int64(size)
        }
        let fileCreationDate = resources?.creationDate
        let fileAddedDate = resources?.addedToDirectoryDate

        let groups = title.groups(for: "([\\w-\\s]+)\\s(\\d+)(?:\\s\\(of \\d+\\))?\\s\\((\\d{4})\\)(?:\\s\\([Dd]igital\\))?\\s\\(([\\w-s\\s]+)\\)")
        title = groups.get(index: 0)?.get(index: 1) ?? title
        let chapter = Double(groups.get(index: 0)?.get(index: 2) ?? "1.0")
        let yearStr = groups.get(index: 0)?.get(index: 3)
        let year = yearStr != nil ? Int(yearStr!) : nil
        var book = Book(id: fileId, url: path, title: title, type: .comic, fileName: path.lastPathComponent, fileSize: fileSize, fileCreationDate: fileCreationDate, fileExt: type, dateAdded: fileAddedDate)
        book.chapter = chapter
        book.year = year

        switch type {
        case "zip", "cbz":
            guard let archive = zipClient.getZIPArchive(for: path) else {
                break
            }
            book.type = .comic
            book.pageCount = archive.reversed().count
            book.thumbnail = Book.Thumb(path: zipClient.getThumbnail(for: archive))
        case "rar", "cbr":
            guard let archive = rarClient.getRARArchive(for: path) else {
                break
            }

            book.type = .comic
            book.pageCount = try? archive.entries().count
            book.thumbnail = Book.Thumb(path: rarClient.getThumbnail(for: archive))

        case "epub":
            ToastManager.shared.info("EPUB files are currently not supported")
        default: break
        }

        return book
    }

    func getImagePaths(for path: URL) throws -> [String] {
        if !path.exists {
            throw Errors.DNE
        }
        switch path.pathExtension {
        case "zip", "cbz":
            if let files = zipClient.getArchiveEntryList(for: path) {
                return files
            } else { throw Errors.FailedToExtractArchive }
        case "rar", "cbr":
            if let files = rarClient.getArchiveEntryList(for: path) {
                return files
            } else { throw Errors.FailedToExtractArchive }
        default: break
        }
        throw Errors.InvalidType
    }

    func getImageData(for id: String, ofName name: String) throws -> Data {
        guard let id = Int64(id), let path = idHash[id]?.url else {
            throw Errors.DNE
        }

        switch path.pathExtension {
        case "zip", "cbz":
            return try zipClient.getImageData(for: path, with: name)
        case "rar", "cbr":
            return try rarClient.getImageData(for: path, with: name)
        default: break
        }
        throw Errors.InvalidType
    }

    func updateBooks() {

        return
        for file in directory.contents.sorted(by: \.lastModified, descending: true) {
            if let book = generateBook(at: file) {
                DispatchQueue.main.async { [weak self] in
                    self?.idHash.updateValue(book, forKey: book.id)
                }

            } else {
                // Don't Delete Temp Files
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func handleDelete(of book: Book) {
        let url = book.url
        idHash.removeValue(forKey: book.id)
        try? FileManager.default.removeItem(at: url)
    }

    func handleRename(of book: Book, to name: String) {
        do {
            let originPath = book.url
            let destinationPath = directory.appendingPathComponent("\(name).\(book.fileExt)")
            try FileManager.default.moveItem(at: originPath, to: destinationPath)
        } catch {
            ToastManager.shared.error(error)
        }
    }

    func generateStored(for book: Book) -> StoredChapter {
        let chapter = StoredChapter()
        chapter.chapterId = String(book.id)
        chapter.title = book.title
        chapter.number = book.chapter ?? 1
        chapter.id = "\(STTHelpers.LOCAL_CONTENT_ID)||\(chapter.chapterId)"
        return chapter
    }
}

// MARK: STTBook

extension LocalContentManager {
    struct Book: Identifiable, Hashable {
        var id: Int64
        var url: URL
        var title: String
        var type: BookType
        var fileName: String
        var thumbnail: Thumb?
        var pageCount: Int?
        var chapter: Double?
        var year: Int?
        var fileSize: Int64?
        var fileCreationDate: Date?
        var fileExt: String
        var dateAdded: Date?

        enum BookType {
            case comic, epub, unknown
        }

        struct Thumb: Hashable {
            var path: String?
        }

        func getThumbnailRequest() -> ImageRequest? {
            guard let thumb = thumbnail, let path = thumb.path else {
                return nil
            }
            var request = ImageRequest(id: hashValue.description) {
                try LocalContentManager.shared.getImageData(for: String(id), ofName: path)
            }
            request.options = .disableDiskCache
            return request
        }

        static func == (lhs: Book, rhs: Book) -> Bool {
            lhs.id == rhs.id
        }

        enum sortOptions: Int, CaseIterable {
            case creationDate, size, title, type, year, dateAdded, lastRead

            var description: String {
                switch self {
                case .title:
                    return "Title"
                case .year:
                    return "Year"
                case .size:
                    return "File Size"
                case .creationDate:
                    return "Creation Date"
                case .type:
                    return "Type"
                case .dateAdded:
                    return "Date Added"
                case .lastRead:
                    return "Last Read"
                }
            }
        }

        func sizeToString() -> String? {
            guard let fileSize = fileSize else {
                return nil
            }

            return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    }
}

extension STTHelpers {
    static func getComicTitle(from str: String) -> String {
        let groups = str.groups(for: "([\\w-\\s]+)\\s(\\d+)(?:\\s\\(of \\d+\\))?\\s\\((\\d{4})\\)(?:\\s\\([Dd]igital\\))?\\s\\(([\\w-s\\s]+)\\)")
        return groups.get(index: 0)?.get(index: 1) ?? str
    }
}

extension STTHelpers {
    static let LOCAL_CONTENT_ID = "7348b86c-ec52-47bf-8069-d30bd8382bf7"
    static let OPDS_CONTENT_ID = "c9d560ee-c4ff-4977-8cdf-fe9473825b8b"
}

extension LocalContentManager {
    class DownloadObject: ObservableObject {
        var url: URL
        var opdsClient: OPDSClient?
        @Published var progress: Double = 0
        var title: String
        var cover: String
        var status: DownloadStatus
        var added: Date
        var request: DownloadRequest?

        init(url: URL, title: String, cover: String) {
            self.url = url
            self.title = title
            self.cover = cover
            status = .queued
            added = .now
        }
    }

    func startDownloadQueue() {
        if let first = downloads.first {
            startDownload(first)
        } else {
            deleteTemp()
        }
    }

    func didFinishLastDownload() {
        guard let target = downloads.popFirst() else {
            deleteTemp()
            return
        }

        if target.status == .failing {
            target.added = .now
            downloads.append(target)
        }

        // New Item At Top, Restart
        startDownloadQueue()
    }

    func deleteTemp() {
        let temp = FileManager.default.documentDirectory.appendingPathComponent("__temp__")
        if temp.contents.isEmpty {
            try? FileManager.default.removeItem(at: temp)
        }
    }

    func addToQueue(_ download: DownloadObject) {
        downloads.append(download)

        if downloads.count == 1 {
            startDownloadQueue()
        }
    }

    func removeFromQueue(_ download: DownloadObject) {
        if download.status == .active {
            download.request?.cancel()
        }
        download.status = .cancelled
        let index = downloads.firstIndex(where: { $0.url == download.url })
        guard let index else { return }
        if index != 1 {
            downloads.remove(at: index)
        }
    }

    func startDownload(_ download: DownloadObject) {
        if download.status != .queued {
            _ = downloads.popFirst()
            didFinishLastDownload()
        }

        let temp = FileManager.default.documentDirectory.appendingPathComponent("__temp__")
        let downloadPath = temp.appendingPathComponent(download.url.lastPathComponent)
        let destination: DownloadRequest.Destination = { _, _ in
            (downloadPath, [.removePreviousFile, .createIntermediateDirectories])
        }

        var headers: HTTPHeaders = .init()
        if let auth = download.opdsClient?.authHeader {
            headers.add(.init(name: "Authorization", value: auth))
        }
        let final = directory.appendingPathComponent(download.url.lastPathComponent)
        download.status = .active
        download.request = AF.download(download.url,
                                       method: .get,
                                       headers: headers,
                                       to: destination)
            .downloadProgress { progress in
                download.progress = progress.fractionCompleted
            }
            .response { response in
                do {
                    let url = try response.result.get()
                    if let url {
                        try FileManager.default.moveItem(at: url, to: final)
                    }
                    download.status = .completed
                } catch {
                    download.status = .failing
                }
                self.didFinishLastDownload()
            }
    }
}
