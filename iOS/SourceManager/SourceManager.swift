//
//  SourceManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-02-24.
//
import Alamofire
import Foundation
import JavaScriptCore
import RealmSwift
import UIKit

final class SourceManager {
    static let shared = SourceManager()
    private let directory = FileManager
        .default
        .applicationSupport
        .appendingPathComponent("Runners", isDirectory: true)

    internal var commons: URL {
        directory
            .appendingPathComponent("common.js")
    }

    var sources: [String: AnyContentSource] = [:]
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
        try? sources[id] ?? startSource(id: id)
    }

    func getContentSource(id: String) throws -> AnyContentSource {
        let initialized = sources[id]

        if let initialized {
            return initialized
        }

        return try startSource(id: id)
    }

    func startSource(id: String) throws -> AnyContentSource {
        let realm = try Realm()
        let runner = realm
            .objects(StoredRunnerObject.self)
            .where { $0.id == id && $0.isDeleted == false && $0.enabled == true }
            .first

        let path = runner?.executable?.filePath
        guard let path else {
            let source = try locateAndSave(id: id, listUrl: runner?.listURL)

            if let source {
                return source
            }
            throw DSK.Errors.NamedError(name: "SourceManager", message: "unable to locate runner executable. Please ensure you have this source installed.")
        }

        let source = try JSCContentSource(path: path)
        sources[id] = source
        return source
    }

    func locateAndSave(id: String, listUrl: String?) throws -> AnyContentSource? {
        let url = try? FileManager
            .default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.isFileURL }
            .filter { $0.lastPathComponent.contains(".stt") }
            .first(where: { $0.lastPathComponent == "\(id).stt" })
        guard let url else {
            return nil
        }

        let source = try JSCContentSource(path: url)
        sources[id] = source
        DataManager.shared.saveRunner(source.info, listURL: listUrl.flatMap { URL(string: $0) }, url: url)
        return source
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
            } catch {
                ToastManager.shared.error("Failed to update commons.")
                Logger.shared.error("\(error)")
            }
            await MainActor.run(body: {
                ToastManager.shared.loading = false
            })
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
        if commons.exists && !StateManager.shared.NetworkStateHigh { // Commons Exists & Device is offline
            return
        }

        let base = URL(string: "https://suwatte.github.io/Common")!
        var url = base.appendingPathComponent("versioning.json")

        let data = try await AF
            .request(url) { $0.timeoutInterval = 2.5 } // Timeout in 2.5 Seconds.
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
        _ = try FileManager.default.replaceItemAt(commons, withItemAt: downloadURL)
        try? FileManager.default.removeItem(at: downloadURL)
        UserDefaults.standard.set(data.version, forKey: STTKeys.JSCommonsVersion)
        await MainActor.run(body: {
            ToastManager.shared.info("Updated Commons")
        })
    }
}

extension SourceManager {
    func startSource(at url: URL) throws -> JSCContentSource {
        try JSCC(path: url)
    }

    @MainActor
    func addSource(_ src: AnyContentSource, listURL: URL? = nil, executable: URL) {
        sources.removeValue(forKey: src.id)
        sources[src.id] = src
        DataManager.shared.saveRunner(src.info, listURL: listURL, url: executable)
    }
}

extension SourceManager {
    @MainActor
    func importRunner(from url: URL) async throws {
        if url.isFileURL {
            try handleFileRunnerImport(from: url)

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
            .sttBase?
            .appendingPathComponent("runners")
            .appendingPathComponent("\(runner.path).stt")
        guard let path else {
            throw DSK.Errors.NamedError(name: "Host", message: "Invalid Runner URL")
        }
        try await handleNetworkRunnerImport(from: path, with: url)
    }

    private func validateRunnerVersion(runner _: AnyContentSource) throws {
        // Validate that the incoming runner has a higher version
//        let current = getSource(id: runner.id)
//
//        if let current = current, current.version > runner.version {
//            throw DSK.Errors.NamedError(name: "Validation", message: "An updated version is already installed.")
//        }
    }

    private func handleFileRunnerImport(from url: URL) throws {
        let runner = try startSource(at: url)
        try validateRunnerVersion(runner: runner)
        let validRunnerPath = directory.appendingPathComponent("\(runner.id).stt")
        _ = try FileManager.default.replaceItemAt(validRunnerPath, withItemAt: url)
        Task { @MainActor in
            addSource(runner, executable: validRunnerPath)
        }
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
        _ = try FileManager.default.replaceItemAt(validRunnerPath, withItemAt: downloadURL)
        try? FileManager.default.removeItem(at: downloadURL)
        await addSource(runner, listURL: list, executable: validRunnerPath)
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
        let runnerList = try await getRunnerList(at: base)
        DataManager.shared.saveRunnerList(runnerList, at: base)
    }
}

// MARK: - URL Events

extension SourceManager {
    func handleGetIdentifier(for _: String) async -> [ContentIdentifier] {
        var results = [ContentIdentifier]()
        for source in sources {
//            do {
//                let result = try await source.getIdentifiers(for: url)
//                if let result = result {
//                    results.append(.init(contentId: result.contentId, sourceId: source.id))
//                }
//            } catch {
//                Logger.shared.error("\(error.localizedDescription)")
//            }
        }
        return results
    }

    @discardableResult
    func handleURL(for url: URL) async -> Bool {
        await MainActor.run {
            ToastManager.shared.loading = true
        }
        let results = await handleGetIdentifier(for: url.relativeString)
        await MainActor.run {
            ToastManager.shared.loading = false
        }
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
//        for result in results {
//            guard let source = getSource(id: result.sourceId) else {
//                continue
//            }
//            // Add Action
//            let action = await UIAlertAction(title: source.name, style: .default) { _ in
//                NavigationModel.shared.identifier = result
//            }
//            await alert.addAction(action)
//        }

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
    func fetchLibraryUpdates() async -> Int {
        let realm = try! Realm(queue: nil)

        // Get Sources
        let sources = realm
            .objects(StoredRunnerObject.self)
            .where { $0.isDeleted == false }
            .where { $0.enabled == true }
            .sorted(by: \.dateAdded)
            .compactMap { try? self.getContentSource(id: $0.id) }

        // Fetch Update For Each Source
        let result = await withTaskGroup(of: Int.self) { group in

            for source in sources {
                group.addTask { [weak self] in
                    do {
                        let updateCount = try await self?.fetchUpdatesForSource(source: source)
                        return updateCount ?? 0
                    } catch {
                        Logger.shared.error("\(error)")
                    }
                    return 0
                }
            }

            var total = 0
            for await result in group {
                total += result
            }
            return total
        }

        UserDefaults.standard.set(Date(), forKey: STTKeys.LastFetchedUpdates)
        return result
    }

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
            let ids = results.map(\.id) as [String]
            let startedTitles = realm
                .objects(ProgressMarker.self)
                .where { $0.id.in(ids) }
                .map(\.id) as [String]

            results = results
                .where { $0.id.in(startedTitles) }
        }
        let library = Array(results.freeze())
        var updateCount = 0
        Logger.shared.log("[\(source.id)] [Updates Checker] Updating \(library.count) titles")
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
                linkedHasUpdate = await linkedHasUpdates(id: entry.id, lowerChapterLimit: lowerChapterLimit)
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
            }

            guard let chapters = chapters else {
                DataManager.shared.updateUnreadCount(for: entry.content!.ContentIdentifier, realm)
                continue
            }
            let sourceId = source.id
            Task {
                let stored = chapters.map { $0.toStoredChapter(withSource: sourceId) }
                DataManager.shared.storeChapters(stored)
                DataManager.shared.updateUnreadCount(for: entry.content!.ContentIdentifier, realm)
            }

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
    func newJSCContext() -> JSContext {
        JSContext(virtualMachine: vm)!
    }

    func add(class cls: AnyClass, name: String, context: JSContext) {
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
    func deleteSource(with id: String) {
        // Remove From Active Runners
//        sources.removeAll(where: { $0.id == id })

        // Remove From Realm
        DataManager.shared.deleteRunner(id)

        // Delete .STT File If present
        Task {
            let path = directory.appendingPathComponent("\(id).stt")
            try? FileManager.default.removeItem(at: path)
        }
    }
}
