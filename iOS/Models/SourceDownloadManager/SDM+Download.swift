//
//  SDM+Download.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Alamofire
import Foundation
import ZIPFoundation

extension SDM {
    private func halt(_ id: String) -> Bool {
        pausedTasks.contains(id) || cancelledTasks.contains(id)
    }

    private func didFinishTasksAtHead(id: String, with state: TaskCompletionState) async {
        if state != .halted {
            // Update Object
            await update(ids: [id], status: state.DownloadState)
            let contentID = await get(id)?.content?.id
            if let contentID {
                let actor = await RealmActor.shared()
                await actor.updateDownloadIndex(for: [contentID])
            }
        }
        // Reset Publisher
        announce()
        isIdle = true
        await clean()
        // Update Queue
        await fetchQueue()
    }

    func download() async {
        // Mark as active
        isIdle = false

        guard let id = queue.first?.id else {
            isIdle = true
            return
        }
        Logger.shared.log("Working: \(id)", CONTEXT)
        await update(ids: [id], status: .active)
        announce(id, state: .fetchingImages)

        do {
            let data = try await getImages(id: id)
            announce(id, state: .downloading(progress: 0.0))
            let completion = try await handleFetchResponse(id: id, urls: data.urls, raws: data.raws, text: data.text)

            guard completion else { return }
            await didFinishTasksAtHead(id: id, with: .completed)
        } catch {
            Logger.shared.error(error, CONTEXT)
            await didFinishTasksAtHead(id: id, with: .failed)
        }
    }

    private func handleFetchResponse(id: String, urls: [URL], raws: [Data], text: String?) async throws -> Bool {
        if let text, !text.isEmpty {
            await setText(id, text)
            return true
        } else if !urls.isEmpty {
            return try await downloadImages(of: id, with: urls)
        } else if !raws.isEmpty {
            return try await writeImages(of: id, with: raws)
        }

        return false
    }
}

extension SDM {
    private func downloadImages(of id: String, with images: [URL]) async throws -> Bool {
        // Make Mutable
        var images = images
        var counter = 1
        let total = images.count

        let identifier = parseID(id)

        let downloadDirectory = folder(for: id, temp: true)

        // Clear, not ideal but removes some bogus edgecases
        try? FileManager.default.removeItem(at: downloadDirectory)

        let source = try await DSK.shared.getContentSource(id: identifier.source)

        // Loop Till all images are downloaded
        while !images.isEmpty {
            // Check Paused or Cancelled
            if halt(id) {
                await didFinishTasksAtHead(id: id, with: .halted)
                return false
            }

            let current = images.popFirst()
            guard let current = current else {
                // Chapter Completed
                break
            }

            var request = URLRequest(url: current)

            // Source Overrides the default image request.
            if source.intents.imageRequestHandler {
                let data = try await source.willRequestImage(imageURL: current)
                let parsedRequest = try data.toURLRequest()
                request = parsedRequest
            }

            let indexName = Double(counter).issue
            let destination: DownloadRequest.Destination = { _, response in
                let pathExtension = response.suggestedFilename?.split(separator: ".").last.flatMap { String($0) } ?? current.pathExtension
                let fileName = "\(indexName).\(pathExtension)"
                let downloadPath = downloadDirectory
                    .appendingPathComponent(fileName)
                return (downloadPath, [.removePreviousFile, .createIntermediateDirectories])
            }

            let task = AF.download(request, to: destination).serializingDownloadedFileURL()

            _ = try await task.result.get()
            let progress = Double(counter) / Double(total)
            announce(id, state: .downloading(progress: progress))
            counter += 1
        }
        // All Images Downloaded
        try await finalize(for: id, at: downloadDirectory)
        return true
    }

    private func writeImages(of id: String, with images: [Data]) async throws -> Bool {
        // Make Mutable
        var images = images
        var counter = 1
        let total = images.count
        let downloadDirectory = folder(for: id, temp: true)
        // Clear Temp Dir
        try? FileManager.default.removeItem(at: downloadDirectory)

        // Loop Till all images are downloaded
        while !images.isEmpty {
            // Check Paused or Cancelled
            if halt(id) {
                await didFinishTasksAtHead(id: id, with: .halted)
                return false
            }

            let current = images.popFirst()
            guard let current = current else {
                // Chapter Completed
                break
            }

            let downloadPath = downloadDirectory.appendingPathComponent("\(counter).png")
            try current.write(to: downloadPath, options: .atomic)
            let progress = Double(counter) / Double(total)
            announce(id, state: .downloading(progress: progress))
            counter += 1
        }
        // All Images Downloaded
        try await finalize(for: id, at: downloadDirectory)
        return true
    }
}

extension SDM {
    private func finalize(for id: String, at directory: URL) async throws {
        announce(id, state: .finalizing)
        let shouldArchiveDownload = Preferences.standard.archiveSourceDownload

        let finalPath = try await shouldArchiveDownload ? archiveCompletedDownload(at: directory, id: id) : moveCompletedDownload(from: directory, id: id)

        // Remove Temp
        do {
            if directory.exists {
                try FileManager.default.removeItem(at: directory)
            }
        } catch {
            Logger.shared.error("Failed to remove temporary download directory for (\(id), \(error.localizedDescription)", CONTEXT)
        }
        // Final Path can either be directory or an archive, update download object
        await finished(id, url: finalPath)
    }

    // Move Out of temporary directory
    private func moveCompletedDownload(from directory: URL, id: String) throws -> URL {
        let destinationFolder = folder(for: id)
        try? FileManager.default.removeItem(at: destinationFolder)

        // Create the destination directory if it doesn't exist.
        let destinationDirectory = destinationFolder.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)

        let destination = destinationDirectory.appendingPathComponent(directory.lastPathComponent)
        try FileManager.default.moveItem(at: directory, to: destination)

        return destination
    }

    // Parse Comic Info & Archive
    private func archiveCompletedDownload(at directory: URL, id: String) async throws -> URL {
        // Images have been downloaded to `directory`, create ComicInfo.xml file
        let xml = await prepareComicInfo(for: id)
        if let xml {
            let path = directory.appendingPathComponent("ComicInfo.xml")
            try xml.write(to: path, atomically: true, encoding: .utf8)
        }

        let archiveName = await prepareArchiveName(for: id) ?? STTHelpers.sha256(of: id)
        let fileName = "\(archiveName).cbz"

        let archivesDirectory = self.directory
            .appendingPathComponent("Archives", isDirectory: true)

        archivesDirectory.createDirectory()
        let path = archivesDirectory
            .appendingPathComponent(fileName)

        let start = Date()
        try FileManager.default.zipItem(at: directory, to: path, shouldKeepParent: true)
        let end = Date()

        let interval = end.timeIntervalSince(start) // Calculate the difference

        Logger.shared.log("Archived Chapter \(id) in \(interval) Seconds", CONTEXT)

        return path
    }
}

extension SDM {
    func folder(for id: String, temp: Bool = false) -> URL {
        let base = temp ? tempDir : directory
        let identifier = parseID(id)
        return base
            .appendingPathComponent(STTHelpers.sha256(of: identifier.source), isDirectory: true)
            .appendingPathComponent(STTHelpers.sha256(of: identifier.content), isDirectory: true)
            .appendingPathComponent(STTHelpers.sha256(of: identifier.chapter), isDirectory: true)
    }
}

extension SDM {
    private func prepareArchiveName(for id: String) async -> String? {
        let download = await get(id)

        guard let download else { return nil }
        var name = ""
        if let title = download.content?.title {
            name += title
        }

        if let volume = download.chapter?.volume {
            name += " Vol. \(volume)"
        }

        if let number = download.chapter?.number {
            name += " (\(number))"
        }

        // Remove potentially invalid characters

        let invalidFileNameCharacters = CharacterSet(charactersIn: ".\\/:*?\"<>|")
        let validFileName = name.components(separatedBy: invalidFileNameCharacters).joined(separator: "")

        if validFileName.isEmpty { return nil }

        return validFileName
    }

    private func prepareComicInfo(for id: String) async -> String? {
        let actor = await RealmActor.shared()
        let identifier = parseID(id)
        let content = await actor.getFrozenContent(id)
        let chapter = await actor.getFrozenChapter(id)
        guard let content, let chapter else { return nil }
        let appVersion = Bundle.main.releaseVersionNumber ?? "0.0.0"
        let components = Calendar.current.dateComponents([.year, .month, .day], from: chapter.date)

        // Build XML String, hacky but should work for our basic usecase
        // Refernce: https://github.com/anansi-project/comicinfo/blob/main/schema/v1.0/ComicInfo.xsd
        var xml = """
        <?xml version='1.0' encoding='utf-8'?>
        <ComicInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        """
        xml += "<Title>\(chapter.title ?? content.title)</Title>\n"
        xml += "<Series>\(content.title)</Series>\n"
        xml += "<Number>\(chapter.number.clean)</Number>\n"
        xml += "<Notes>Tagged By Suwatte v\(appVersion) on \(Date.now.iso8601)</Notes>\n"

        if let volume = chapter.volume.flatMap({ Int($0) }) {
            xml += "<Volume>\(volume)</Volume>\n"
        }

        if let creator = content.creators.first {
            xml += "<Writer>\(creator)</Writer>\n"
        }
        if let summary = content.summary {
            xml += "<Summary>\(summary)</Summary>\n"
        }

        if let web = content.webUrl {
            xml += "<Web>\(web)</Web>\n"
        }

        if let year = components.year {
            xml += "<Year>\(year)</Year>\n"
        }

        if let month = components.month {
            xml += "<Month>\(month)</Month>\n"
        }

        if let day = components.day {
            xml += "<Day>\(day)</Day>\n"
        }

        if content.contentType == .manga {
            xml += "<Manga>Yes</Manga>"
        }
        xml += "</ComicInfo>"

        return xml
    }
}
