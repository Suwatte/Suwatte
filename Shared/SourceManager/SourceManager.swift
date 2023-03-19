//
//  SourceManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-02-24.
//
import Alamofire
import Foundation
import RealmSwift
import JavaScriptCore
import UIKit

final class SourceManager: ObservableObject {
    static let shared = SourceManager()
    private let directory = FileManager
        .default
        .applicationSupport
        .appendingPathComponent("Runners", isDirectory: true)

    internal var commons: URL {
        directory
            .appendingPathComponent("common.js")
    }

    @Published var sources: [AnyContentSource] = []
    private let vm: JSVirtualMachine
    init() {

        // Create Directory
        directory.createDirectory()
        let queue = DispatchQueue(label: "com.ceres.suwatte.daisuke", attributes: .concurrent)
        vm = queue.sync { JSVirtualMachine()! }
        log("Initializing...")
        start()
    }
}

// MARK: - Public

extension SourceManager {
    func getSource(id: String) -> AnyContentSource? {
        sources.first(where: { $0.id == id })
    }
}

// MARK: - Log

extension SourceManager {
    func log(lvl: Logger.Level = .log, _ message: String) {
        Logger.shared.log(level: lvl, message, "SourceManager")
    }
}

// MARK: Start Up

extension SourceManager {
    func start() {
        Task {
            do {
                try await getDependencies()
                await startJSCSources()
            } catch {
                ToastManager.shared.error("Failed to Start Runners")
                Logger.shared.error("\(error)")
            }
            await MainActor.run(body: {
                ToastManager.shared.loading = false
            })
        }
    }

    func startJSCSources() async {
        let urls = try? FileManager
            .default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.isFileURL }

        guard let urls = urls?.filter({ $0.lastPathComponent.contains(".stt") }) else {
            return
        }
        for url in urls {
            do {
                let source = try startSource(at: url)
                await addSource(source)
            } catch {
                Logger.shared.error("Failed to start source, \(error)")
            }

        }
    }

    func getDependencies() async throws {
        await MainActor.run(body: {
            ToastManager.shared.loading = true
        })
        
        do {
            try await getCommons()
        } catch {
            if !commons.exists {
                throw DSK.Errors.NamedError(name: "Commons", message: "Common Libraries Not Installed")
            }
        }
    }

    private func getCommons() async throws {
        let base = URL(string: "https://suwatte.github.io/Common")!
        var url = base.appendingPathComponent("versioning.json")

        let data = try await AF
            .request(url)
            .validate()
            .serializingDecodable(DSKCommon.JSCommon.self)
            .value
        let saved = UserDefaults.standard.string(forKey: STTKeys.JSCommonsVersion)
        let shouldRedownload = !commons.exists || saved == nil || [ComparisonResult.orderedDescending].contains(data.version.compare(saved!))
        if !shouldRedownload {
            return
        }

        url = base.appendingPathComponent("lib.js")
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)

        let tempLocation = directory
            .appendingPathComponent("__temp__", isDirectory: true)
            .appendingPathComponent("lib.js")

        let destination: DownloadRequest.Destination = { _, _ in
            (tempLocation, [.removePreviousFile, .createIntermediateDirectories])
        }
        let request = AF.download(req, to: destination)
        let downloadURL = try await request.serializingDownloadedFileURL().result.get()
        let _ = try FileManager.default.replaceItemAt(commons, withItemAt: downloadURL)
        try? FileManager.default.removeItem(at: downloadURL)
        UserDefaults.standard.set(data.version, forKey: STTKeys.JSCommonsVersion)
        await MainActor.run(body: {
            ToastManager.shared.info("Updated Commons")
        })
    }
}

extension SourceManager {
    func startSource(at url: URL) throws -> JSCContentSource {
        let source = try JSCContentSource(path: url)
        return source
    }

    @MainActor
    func addSource(_ src: AnyContentSource, listURL: URL? = nil) {
        sources.removeAll(where: { $0.id == src.id })
        sources.append(src)
        
        Task.detached {
            DataManager.shared.saveRunner(src.info, listURL: listURL)
        }
    }
}

extension SourceManager {
    @MainActor
    func importRunner(from url: URL) async throws {
        if url.isFileURL {
            try await handleFileRunnerImport(from: url)

        } else {
            try await handleNetworkRunnerImport(from: url)
        }
    }

    @MainActor
    func importRunner(from url: URL, with id: String) async throws {
        let list = try await getRunnerList(at: url)

        let runner = list.runners.first(where: { $0.id == id })

        guard let runner = runner else {
            return
        }

        let path = url
            .appendingPathComponent("runners")
            .appendingPathComponent("\(runner.path).stt")
        try await handleNetworkRunnerImport(from: path, with: url)
    }

    private func validateRunnerVersion(runner: AnyContentSource) throws {
        // Validate that the incoming runner has a higher version
        let current = getSource(id: runner.id)

        if let current = current, current.version > runner.version {
            throw DSK.Errors.NamedError(name: "Validation", message: "An updated version is already installed.")
        }
    }

    private func handleFileRunnerImport(from url: URL) async throws {
        let runner = try startSource(at: url)
        try validateRunnerVersion(runner: runner)
        let validRunnerPath = directory.appendingPathComponent("\(runner.id).stt")
        let _ = try FileManager.default.replaceItemAt(validRunnerPath, withItemAt: url)
        await addSource(runner)
    }

    private func handleNetworkRunnerImport(from url: URL, with list: URL? = nil) async throws {
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        let path = url.lastPathComponent
        let tempLocation = directory
            .appendingPathComponent("__temp__")
            .appendingPathComponent(path)

        let destination: DownloadRequest.Destination = { _, _ in
            (tempLocation, [.removePreviousFile, .createIntermediateDirectories])
        }
        let request = AF.download(req, to: destination)

        let downloadURL = try await request.serializingDownloadedFileURL().result.get()

        let runner = try startSource(at: downloadURL)

        try validateRunnerVersion(runner: runner)
        let validRunnerPath = directory.appendingPathComponent("\(runner.id).stt")
        let _ = try FileManager.default.replaceItemAt(validRunnerPath, withItemAt: downloadURL)
        try? FileManager.default.removeItem(at: downloadURL)

        Task { @MainActor in
            addSource(runner, listURL: list)
        }
    }

    func getRunnerList(at url: URL) async throws -> RunnerList {
        let listUrl = url.lastPathComponent == "runners.json" ? url : url.runnersListURL
        let req = URLRequest(url: listUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        let task = AF.request(req).validate().serializingDecodable(RunnerList.self)

        let runnerList = try await task.value
        return runnerList
    }

    // Get Source List Info
    func saveRunnerList(at url: String) async throws {
        // Get runner list
        let base = URL(string: url)
        guard let base else {
            throw DSK.Errors.NamedError(name: "Validation", message: "Invalid URL")
        }
        let url = base.runnersListURL
        let runnerList = try await getRunnerList(at: url)
        DataManager.shared.saveRunnerList(runnerList, at: url)
    }
}

// MARK: - URL Events

extension SourceManager {
    func handleGetIdentifier(for url: String) async -> [ContentIdentifier] {
        var results = [ContentIdentifier]()
        for source in sources {
            do {
                let result = try await source.getIdentifiers(for: url)
                if let result = result {
                    results.append(.init(contentId: result.contentId, sourceId: source.id))
                }
            } catch {
                Logger.shared.error("\(error.localizedDescription)")
            }
        }
        return results
    }

    @discardableResult
    func handleURL(for url: URL) async -> Bool {
        let results = await handleGetIdentifier(for: url.relativeString)

        if results.isEmpty {
            return false
        }
        if results.count == 1 {
            // Only One Result, navigate immediately
            await MainActor.run(body: {
                NavigationModel.shared.identifier = results.first
            })
            return true
        }

        // Show Alert
        let alert = await UIAlertController(title: "Handler", message: "Multiple Content Sources can handle this url", preferredStyle: .actionSheet)

        // Add Actions
        for result in results {
            guard let source = getSource(id: result.sourceId) else {
                continue
            }
            // Add Action
            let action = await UIAlertAction(title: source.name, style: .default) { _ in
                NavigationModel.shared.identifier = result
            }
            await alert.addAction(action)
        }

        let cancel = await UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        await alert.addAction(cancel)

        // Present
        await MainActor.run(body: {
            KEY_WINDOW?.rootViewController?.present(alert, animated: true)
        })

        return true
    }
}

// MARK: - Updates

extension SourceManager {
    func handleBackgroundLibraryUpdate() async -> Int {
        return await fetchLibaryUpdates()
    }

    func handleForegroundLibraryUpdate() async -> Int {
        return await fetchLibaryUpdates()
    }

    private func fetchLibaryUpdates() async -> Int {
        let result = await withTaskGroup(of: Int.self, body: { group in

            for source in sources {
                group.addTask {
                    let count = try? await self.fetchUpdatesForSource(source: source)
                    return count ?? 0
                }
            }

            var total = 0
            for await result in group {
                total += result
            }
            return total
        })
        UserDefaults.standard.set(Date(), forKey: STTKeys.LastFetchedUpdates)
        return result
    }

    @MainActor
    private func fetchUpdatesForSource(source: AnyContentSource) async throws -> Int {
        let realm = try! Realm(queue: nil)
        let date = UserDefaults.standard.object(forKey: STTKeys.LastFetchedUpdates) as! Date
        let skipConditions = Preferences.standard.skipConditions
        let validStatuses = [ContentStatus.ONGOING, .HIATUS, .UNKNOWN]
        var results = realm.objects(LibraryEntry.self)
            .where { $0.content != nil }
            .where { $0.dateAdded < date }
            .where { $0.content.sourceId == source.id }
            .where { $0.content.status.in(validStatuses) }

        // Flag Not Set to Reading Skip Condition
        if skipConditions.contains(.INVALID_FLAG) {
            results = results
                .where { $0.flag == .reading }
        }
        // Title Has Unread Skip Condition
        if skipConditions.contains(.HAS_UNREAD) {
            results = results
                .where { $0.unreadCount == 0 }
        }
        // Title Has No Markers, Has not been started
        if skipConditions.contains(.NO_MARKERS) {
            let startedTitles = realm
                .objects(ChapterMarker.self)
                .where { $0.completed == true }
                .where { $0.chapter != nil }
                .where { $0.chapter.sourceId == source.id }
                .distinct(by: [\.chapter?.sourceId, \.chapter?.contentId])
                .map { ContentIdentifier(contentId: $0.chapter!.contentId, sourceId: $0.chapter!.sourceId).id } as [String]

            results = results
                .where { $0._id.in(startedTitles) }
        }
        let library = results.map { $0 } as [LibraryEntry]
        var updateCount = 0
        Logger.shared.log("[DAISUKE] [UPDATER] [\(source.id)] \(library.count) Titles Matching")
        for entry in library {
            guard let contentId = entry.content?.contentId else {
                continue
            }

            // Fetch Chapters
            let chapters = try? await getChapters(for: contentId, with: source)
            let marked = try? await(source as? (any SyncableSource))?.getReadChapterMarkers(contentId: contentId)
            let lastFetched = DataManager.shared.getLatestStoredChapter(source.id, contentId)
            // Calculate Update Count
            var filtered = chapters?
                .filter { $0.date > entry.lastUpdated }
                .filter { $0.date > entry.lastOpened }

            // Marked As Read on Source
            if let marked {
                filtered = filtered?
                    .filter { !marked.contains($0.chapterId) }
            }

            // Already Fetched on Source
            if let lastFetched, let lastFetchedUpdatedIndex = chapters?
                .first(where: { $0.chapterId == lastFetched.chapterId })?
                .index
            {
                filtered = filtered?
                    .filter { $0.index < lastFetchedUpdatedIndex }
            }
            var updates = filtered?.count ?? 0

            let checkLinked = UserDefaults.standard.bool(forKey: STTKeys.CheckLinkedOnUpdateCheck)
            var linkedHasUpdate = false
            if checkLinked {
                let lowerChapterLimit = filtered?.sorted(by: { $0.number < $1.number }).last?.number ?? lastFetched?.number
                linkedHasUpdate = await linkedHasUpdates(id: entry._id, lowerChapterLimit: lowerChapterLimit)
                if linkedHasUpdate, updates == 0 { updates += 1 }
            }
            // No Updates Return 0
            if updates == 0 {
                continue
            }

            // New Chapters Found, Update Library Entry Object
            try! realm.safeWrite {
                entry.lastUpdated = chapters?.sorted(by: { $0.date > $1.date }).first?.date ?? Date()
                entry.updateCount += updates
                if !entry.linkedHasUpdates, linkedHasUpdate {
                    entry.linkedHasUpdates = true
                }
                // Update Chapters
                let stored = chapters?
                    .map { $0.toStoredChapter(withSource: source.id) }
                if let stored {
                    realm.add(stored, update: .modified)
                }
            }

            // Update Unread Count
            DataManager.shared.updateUnreadCount(for: entry.content!.ContentIdentifier, realm)

            updateCount += updates
        }

        return updateCount
    }

    private func getChapters(for id: String, with source: AnyContentSource) async throws -> [DSKCommon.Chapter] {
        let shouldUpdateProfile = UserDefaults.standard.bool(forKey: STTKeys.UpdateContentData)

        if shouldUpdateProfile {
            let profile = try? await source.getContent(id: id)
            if let stored = try? profile?.toStoredContent(withSource: source.id) {
                DataManager.shared.storeContent(stored)
            }

            if let chapters = profile?.chapters {
                return chapters
            }
        }

        let chapters = try await source.getContentChapters(contentId: id)
        return chapters
    }

    @MainActor
    func linkedHasUpdates(id: String, lowerChapterLimit: Double?) async -> Bool {
        let linked = DataManager.shared.getLinkedContent(for: id)

        for title in linked {
            guard let source = getSource(id: title.sourceId) else { continue }
            guard let chapters = try? await source.getContentChapters(contentId: title.contentId) else { continue }
            let marked = try? await(source as? (any SyncableSource))?.getReadChapterMarkers(contentId: title.contentId)
            let lastFetched = DataManager.shared.getLatestStoredChapter(source.id, title.contentId)
            var filtered = chapters

            if let lowerChapterLimit {
                filtered = filtered
                    .filter { $0.number > lowerChapterLimit }
            }

            // Marked As Read on Source
            if let marked {
                filtered = filtered
                    .filter { !marked.contains($0.chapterId) }
            }

            // Already Fetched on Source
            if let lastFetched, let lastFetchedUpdatedIndex = chapters
                .first(where: { $0.chapterId == lastFetched.chapterId })?
                .index
            {
                filtered = filtered
                    .filter { $0.index < lastFetchedUpdatedIndex }
            }

            if !filtered.isEmpty { return true }
        }
        return false
    }
}


extension SourceManager {
    
    internal func newJSCContext() -> JSContext {
        JSContext(virtualMachine: vm)!
    }
    
    internal func add(class cls: AnyClass, name: String, context: JSContext) {
        let constructorName = "__constructor__\(name)"
        
        let constructor: @convention(block) () -> NSObject = {
            let cls = cls as! NSObject.Type
            return cls.init()
        }
        
        context.setObject(unsafeBitCast(constructor, to: AnyObject.self),
                          forKeyedSubscript: constructorName as NSCopying & NSObjectProtocol)
        
        let script = "function \(name)() " +
        "{ " +
        "   var obj = \(constructorName)(); " +
        "   obj.setThisValue(obj); " +
        "   return obj; " +
        "} "
        
        context.evaluateScript(script)
    }
}


extension SourceManager {
    func deleteSource(with id: String ) {
        // Remove From Active Runners
        sources.removeAll(where: { $0.id == id })
        
        // Remove From Realm
        DataManager.shared.deleteRunner(id)
        
        // Delete .STT File If present
        Task {
            let path = directory.appendingPathComponent("\(id).stt")
            try? FileManager.default.removeItem(at: path)
        }
    }
}