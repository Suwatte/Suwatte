//
//  ICDM.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-08.
//

import Alamofire
import Combine
import Foundation
import RealmSwift
import Unrar

// MARK: Define

typealias ICDM = InteractorContentDownloader
final class InteractorContentDownloader: ObservableObject {
    static let shared = InteractorContentDownloader()
    let directory = FileManager.default.applicationSupport.appendingPathComponent("Downloads", isDirectory: true)
    var tempDir: URL {
        directory.appendingPathComponent("__temp__")
    }

    private var pausedTasks = [String]()
    private var cancelledTasks = [String]()
    var isIdle = true

    init() {
        directory.createDirectory()
        tempDir.createDirectory()
        Logger.shared.log("[ICDM] Resource Initialized")
        resetActives()
        fire()
        runTasks()
    }

    var activeDownloadPublisher: CurrentValueSubject<(ChapterIndentifier, ActiveDownloadState)?, Never> = .init(nil)
    func announce(_ ids: ChapterIndentifier, state: ActiveDownloadState) async {
        await MainActor.run(body: {
            activeDownloadPublisher.send((ids, state))
        })
    }
}

extension ICDM {
    var queue: [ICDMDownloadObject] {
        let realm = try! Realm()

        return realm.objects(ICDMDownloadObject.self)
            .where {
                $0.status == .queued
            }
            .toArray()
    }
}

// MARK: Queue Control

extension ICDM {
    func resetActives() {
        // mark, active downloads as queued
        let realm = try! Realm()

        let objects = realm.objects(ICDMDownloadObject.self).where { $0.status == .active }

        try! realm.safeWrite {
            objects.forEach { object in
                object.status = .queued
            }
        }
    }

    func resume(ids: [String]) {
        let realm = try! Realm()
        let targets = realm.objects(ICDMDownloadObject.self).where { $0._id.in(ids) }

        try! realm.safeWrite {
            targets.forEach { d in
                d.status = .queued
            }
        }

        pausedTasks.removeAll(where: ids.contains(_:))
        fire()
    }

    func start() async {
        isIdle = false
        await download()
    }

    func pause(ids: [String]) {
        pausedTasks.append(contentsOf: ids)
        pausedTasks = Array(Set(pausedTasks))

        let realm = try! Realm()
        let targets = realm
            .objects(ICDMDownloadObject.self)
            .where { $0._id.in(ids) }
//
        try! realm.safeWrite {
            targets.forEach { target in
                target.status = .paused
            }
        }
    }

    func cancel(ids: [String]) {
        cancelledTasks.append(contentsOf: ids)
        cancelledTasks = Array(Set(cancelledTasks))

        let realm = try! Realm()
        let targets = realm
            .objects(ICDMDownloadObject.self)
            .where { $0._id.in(ids) }

        try! realm.safeWrite {
            targets.forEach { target in
                target.status = .cancelled
            }
        }

        runTasks()
    }

    private func clean() {
        cancelledTasks.forEach { id in
            let manager = FileManager.default
            try? manager.removeItem(at: directory.appendingPathComponent(id))
            try? manager.removeItem(at: tempDir.appendingPathComponent(id))
        }
    }

    func fire() {
        let queue = queue
        if isIdle && !queue.isEmpty {
            Task {
                await start()
            }
        }
    }

    func shouldStopTask(id: String) -> Bool {
        pausedTasks.contains(id) || cancelledTasks.contains(id)
    }

    func runTasks() {
        // Delete Cancelled Objects
        let realm = try! Realm()
        let targets = realm
            .objects(ICDMDownloadObject.self)
            .where { $0.status == .cancelled }
        cancelledTasks.append(contentsOf: targets.map { $0._id })
        clean()

        Logger.shared.log("[ICDM] Deleting \(targets.count) Objects")
        try! realm.safeWrite {
            realm.delete(targets)
        }

        cancelledTasks.removeAll()
    }
}

//
extension ICDM {
    func add(chapters: [StoredChapter]) {
        let ids = chapters.map { $0._id }
        let realm = try! Realm()

        let completedIds = realm
            .objects(ICDMDownloadObject.self)
            .where { $0._id.in(ids) && $0.status == .completed && $0.status != .active }
            .map { $0._id }

        let targets = chapters.filter { !completedIds.contains($0._id) }

        let objects = targets.sorted(by: { $0.index > $1.index }).map { chapter -> ICDMDownloadObject in
            let dObject = ICDMDownloadObject()
            dObject.chapter = chapter
            dObject.status = .queued
            return dObject
        }

        try! realm.safeWrite {
            realm.add(objects, update: .modified)
        }

        fire()
    }
}

//
extension ICDM {
    private func getImages(of ids: ChapterIndentifier) async throws -> (urls: [URL], raws: [Data], text: String) {
        let source = DaisukeEngine.shared.getSource(with: ids.source)

        guard let source = source else {
            throw DaisukeEngine.Errors.NamedError(name: "Downloads", message: "Source Not Found")
        }

        let data = try await source.getChapterData(contentId: ids.content, chapterId: ids.chapter)

        let urls = data.pages?.compactMap { URL(string: $0.url ?? "") } ?? []
        let b64Raws = data.pages?.compactMap { $0.raw?.toBase64() } ?? []
        let raws = b64Raws.compactMap { Data(base64Encoded: $0) }
        let text = data.text ?? ""
        return (urls: urls, raws: raws, text: text)
    }
}

extension ICDM {
    private func markDownload(of ids: ChapterIndentifier, as status: DownloadStatus) {
        let realm = try! Realm()

        let id = generateID(of: ids)
        let obj = realm.objects(ICDMDownloadObject.self).first(where: { $0._id == id })

        try! realm.safeWrite {
            obj?.status = status
        }
    }
}

//
extension ICDM {
    enum TaskCompletionState {
        case completed, failed, cancelled
    }

    enum ActiveDownloadState {
        case fetchingImages, downloading(progress: Double), finalizing
    }

    private func didFinishTasksAtHead(of ids: ChapterIndentifier, with state: TaskCompletionState) async {
        // Update Object

        if state != .cancelled {
            markDownload(of: ids, as: state == .completed ? .completed : .failing)
        } else {
            let id = generateID(of: ids)
            // Remove From Task List
            pausedTasks.removeAll(where: { $0 == id })
            cancelledTasks.removeAll(where: { $0 == id })
        }

        // Reset Publisher
        await MainActor.run(body: {
            activeDownloadPublisher.send(nil)
        })
        // Move to Next
        await download()
    }

    private func download() async {
        // Mark as active
        isIdle = false

        guard let ids = queue.first?.getIdentifiers() else {
            Logger.shared.log("[ICDM] Queue Empty")
            isIdle = true
            return
        }

        markDownload(of: ids, as: .active)

        // Get images
        await announce(ids, state: .fetchingImages)
        let data = try? await getImages(of: ids)

        guard let data = data else {
            await didFinishTasksAtHead(of: ids, with: .failed)
            return
        }

        await announce(ids, state: .downloading(progress: 0.0))
        do {
            if !data.text.isEmpty {
                setText(for: generateID(of: ids), with: data.text)
                await didFinishTasksAtHead(of: ids, with: .completed)
            } else if !data.urls.isEmpty {
                // Handle URL List
                let completion = try await downloadImages(of: ids, with: data.urls)
                if completion {
                    await didFinishTasksAtHead(of: ids, with: .completed)
                }
            } else if !data.raws.isEmpty {
                // Handle Raws
                let completion = try await writeImages(of: ids, with: data.raws)
                if completion {
                    await didFinishTasksAtHead(of: ids, with: .completed)
                }
            } else {
                throw DaisukeEngine.Errors.MethodNotImplemented
            }
        } catch {
            Logger.shared.error("[ICDM] [\(generateID(of: ids))] \(error.localizedDescription)")
            await didFinishTasksAtHead(of: ids, with: .failed)
            return
        }
    }

    private func setText(for id: String, with data: String) {
        let realm = try! Realm()

        guard let obj = realm.objects(ICDMDownloadObject.self)
            .where({ $0._id == id })
            .first
        else {
            return
        }

        try! realm.safeWrite {
            obj.textData = data
        }
    }

    private func downloadImages(of ids: ChapterIndentifier, with images: [URL]) async throws -> Bool {
        // Make Mutable
        var images = images
        var counter = 1
        let total = images.count
        let id = generateID(of: ids)

        // Clear Temp Dir
        let downloadDir = tempDir.appendingPathComponent(id)

        // Check if The Folder has some downloads
        let urls = downloadDir.contents

        if !urls.isEmpty {
            counter = urls.count - 1
            images = Array(images[counter...])
        } else {
            try? FileManager.default.removeItem(at: downloadDir)
        }

        // Loop Till all images are downloaded
        while !images.isEmpty {
            // Check Paused or Cancelled
            if shouldStopTask(id: id) {
                await didFinishTasksAtHead(of: ids, with: .cancelled)
                return false
            }

            let current = images.popFirst()
            guard let current = current else {
                // Chapter Completed
                break
            }

            let downloadPath = downloadDir.appendingPathComponent("\(counter).\(current.pathExtension)")
            let destination: DownloadRequest.Destination = { _, _ in
                (downloadPath, [.removePreviousFile, .createIntermediateDirectories])
            }

            let task = AF.download(current, to: destination).serializingDownloadedFileURL()

            _ = try await task.result.get()
            await announce(ids, state: .downloading(progress: Double(counter) / Double(total)))

            counter += 1
        }
        // All Images Downloaded
        try finalize(for: ids, at: downloadDir)
        return true
    }

    private func writeImages(of ids: ChapterIndentifier, with images: [Data]) async throws -> Bool {
        // Make Mutable
        var images = images
        var counter = 1
        let total = images.count
        let id = generateID(of: ids)
        // Clear Temp Dir
        let downloadDir = tempDir.appendingPathComponent(id)
        try? FileManager.default.removeItem(at: downloadDir)

        // Loop Till all images are downloaded
        while !images.isEmpty {
            // Check Paused or Cancelled
            if shouldStopTask(id: id) {
                await didFinishTasksAtHead(of: ids, with: .cancelled)
                return false
            }

            let current = images.popFirst()
            guard let current = current else {
                // Chapter Completed
                break
            }

            let downloadPath = downloadDir.appendingPathComponent("\(counter).png")
            try current.write(to: downloadPath, options: .atomic)
            await announce(ids, state: .downloading(progress: Double(counter) / Double(total)))

            counter += 1
        }
        // All Images Downloaded
        try finalize(for: ids, at: downloadDir)
        return true
    }

    func generateID(of ids: ChapterIndentifier) -> String {
        "\(ids.source)||\(ids.content)||\(ids.chapter)"
    }

    private func finalize(for ids: ChapterIndentifier, at path: URL) throws {
        DispatchQueue.main.async {
            self.activeDownloadPublisher.send((ids, .finalizing))
        }
        let id = generateID(of: ids)
        let destination = directory.appendingPathComponent("\(id)")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: path, to: destination)
    }

    func getCompletedDownload(for id: String) throws -> DownloadedChapter? {
        let realm = try Realm()
        let obj = realm.objects(ICDMDownloadObject.self)
            .where { $0._id == id }
            .where { $0.status == .completed }
            .first

        guard let obj = obj else {
            return nil
        }

        // Text
        if let text = obj.textData {
            return .init(text: text)
        }

        // Images
        let directory = ICDM.shared.directory.appendingPathComponent(id)
        if directory.exists {
            var urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            urls = urls
                .sorted(by: { STTHelpers.optionalCompare(firstVal: Int($0.fileName), secondVal: Int($1.fileName)) })
            return .init(urls: urls)
        }
        return nil
    }

    struct DownloadedChapter {
        var text: String?
        var urls: [URL]?
    }
}

extension URL {
    var fileName: String {
        let fileExt = pathExtension

        return lastPathComponent.replacingOccurrences(of: ".\(fileExt)", with: "")
    }
}
