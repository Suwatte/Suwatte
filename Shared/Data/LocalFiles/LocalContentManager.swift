//
//  LocalContentManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-07.
//

import Foundation
import Kingfisher
import UIKit
final class LocalContentManager: ObservableObject {
    @Published var isSelecting = false
    @Published var idHash: [Int64: Book] = [:]

    private var observer: DispatchSourceFileSystemObject?
    static var shared = LocalContentManager()
    let directory = FileManager.default.documentDirectory.appendingPathComponent("LocalContent", isDirectory: true)
    internal let zipClient = ZipClient()
    internal let rarClient = RarClient()
    init() {
        directory.createDirectory()

        // Only Observe When App is in the foreground.
        // This behaviour should change when in the event of a switch to a more panels like approach to file management
        observer = observeDirectory()
    }

    // Reference: https://medium.com/over-engineering/monitoring-a-folder-for-changes-in-ios-dc3f8614f902
    func observeDirectory() -> DispatchSourceFileSystemObject? {
        let descriptor = open(directory.path, O_EVTONLY)
        let observer = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .global(qos: .utility))
        observer.setEventHandler { [weak self] in
            print("[LOCAL CM]", "Event Caught")
            self?.updateBooks()
        }

        observer.setRegistrationHandler { [weak self] in
            print("[LOCAL CM]", "Observer Registered")
            self?.updateBooks()
        }

        observer.setCancelHandler {
            print("[LOCAL CM]", "Closing Observer")
            close(descriptor)
        }
        observer.resume()
        return observer
    }

    deinit {
        observer?.cancel()
    }

    enum Errors: Error {
        case FileExists
        case DNE
        case InvalidType
        case FailedToExtractArchive
        case BookGenerationFailed
    }

    func getBook(withId id: Int64) -> Book? {
        idHash[id]
    }

    func importFile(at url: URL) throws {
        let targetLocation = directory.appendingPathComponent(url.lastPathComponent)
        if targetLocation.exists {
            print("File Exists")
            throw Errors.FileExists
        }
        try FileManager.default.copyItem(at: url, to: targetLocation)
    }

    func generateBook(at path: URL) -> Book? {
        if path.hasDirectoryPath {
            return nil
        }
        let type = path.pathExtension
        if !["cbz", "cbr", "epub", "rar", "zip"].contains(type) {
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

        default: break
        }

        //        print("Done - ", book.title)
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
        case "cbz":
            return try zipClient.getImageData(for: path, with: name)
        case "cbr":
            return try rarClient.getImageData(for: path, with: name)
        default: break
        }
        throw Errors.InvalidType
    }

    func updateBooks() {
        for file in directory.contents.sorted(by: \.lastModified, descending: true) {
            if let book = generateBook(at: file) {
                DispatchQueue.main.async { [weak self] in
                    self?.idHash.updateValue(book, forKey: book.id)
                }

            } else {
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
            print(error)
            ToastManager.shared.setError(error: error)
        }
    }

    func generateStored(for book: Book) -> StoredChapter {
        let chapter = StoredChapter()
        chapter.sourceId = STTHelpers.LOCAL_CONTENT_ID
        chapter.contentId = String(book.id)
        chapter.chapterId = ""
        chapter.title = book.title
        chapter.number = book.chapter ?? 1
        chapter._id = "\(chapter.sourceId)||\(chapter.contentId)||\(chapter.chapterId)"
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

        func getImageSource() -> Kingfisher.Source? {
            guard let thumb = thumbnail else {
                return nil
            }
            if let path = thumb.path {
                return .provider(LocalContentImageSwiftUIProvider(fileId: String(id), entryPath: path))
            }
            return nil
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
