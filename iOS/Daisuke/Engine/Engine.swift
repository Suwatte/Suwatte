//
//  Engine.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Alamofire
import Foundation
import JavaScriptCore
import RealmSwift

final actor DaisukeEngine {
    // MARK: Singleton

    static let shared = DaisukeEngine()

    let directory = FileManager
        .default
        .applicationSupport
        .appendingPathComponent("Runners", isDirectory: true)

    var commons: URL {
        directory
            .appendingPathComponent("common.js")
    }

    private var runners: [String: AnyRunner] = [:]
    let vm: JSVirtualMachine

    init() {
        // Create Directory if required
        if !directory.exists {
            directory.createDirectory()
        }

        // Start VM
        let queue = DispatchQueue(label: "com.ceres.suwatte.daisuke.jsc", attributes: .concurrent)
        vm = queue.sync { JSVirtualMachine()! }

        // Simple Log Message
        Logger.shared.log(level: .log, "Engine Ready!", "DaisukeEngine")
    }

    func getCommons() {
        if !commons.exists {
            Task {
                await MainActor.run {
                    ToastManager.shared.loading = true
                }
                do {
                    try await downloadCommonsIfNecessary()
                } catch {
                    Logger.shared.error(error, "Daisuke")
                    Task { @MainActor in
                        StateManager.shared.alert(title: "Error", message: "Failed to download commons library. Without this runners will not function")
                    }
                }

                Task { @MainActor in
                    ToastManager.shared.loading = false
                }
            }
        }
    }
}

extension DaisukeEngine {
    private func executeableURL(for id: String) -> URL {
        let fileName = STTHelpers.sha256(of: id) + ".stt"
        let file = directory
            .appendingPathComponent(fileName)
        return file
    }

    private func validateRunnerVersion(runner: AnyRunner) async throws {
        // Validate that the incoming runner has a higher version
        let current = await getRunner(runner.id)

        if let current = current, current.version > runner.version {
            throw DSK.Errors.NamedError(name: "Validation", message: "An updated version is already installed.")
        }
    }
}

// MARK: - Runner Start Up

extension DaisukeEngine {
    func startRunner(_ id: String) async throws -> AnyRunner {
        let actor = await RealmActor.shared()
        let file = await actor.getRunnerExecutable(id: id)

        guard let file, file.exists else {
            let standardLocation = executeableURL(for: id)
            if standardLocation.exists {
                return try await startRunner(standardLocation, for: id)
            } else {
                throw DSK.Errors.RunnerExecutableNotFound(id: id)
            }
        }

        return try await startRunner(file, for: id)
    }

    func startRunner(_ url: URL, for id: String? = nil) async throws -> AnyRunner {
        let content = try String(contentsOf: url, encoding: .utf8)
        let hasWKDirective = content.contains("dsk use webkit")
        let alwaysUseWKDirective = UserDefaults.standard.bool(forKey: STTKeys.UseWebKitDirective)
        let runner = try await hasWKDirective || alwaysUseWKDirective ? startWKRunner(with: url, for: id) : startJSCRunner(with: url, for: id)

        didStartRunner(runner)
        return runner
    }
}

// MARK: - Runner Management

extension DaisukeEngine {
    func getDSKRunner(_ id: String) async throws -> AnyRunner {
        if let runner = runners[id] {
            return runner
        }

        return try await startRunner(id)
    }

    func getRunner(_ id: String) async -> AnyRunner? {
        do {
            return try await getDSKRunner(id)
        } catch {
            Logger.shared.error("[\(id)] [Requested] \(error.localizedDescription)")
            return nil
        }
    }

    func addRunner(_ rnn: AnyRunner, listURL _: URL? = nil) {
        runners.removeValue(forKey: rnn.id)
        runners[rnn.id] = rnn
    }

    func didStartRunner(_ runner: AnyRunner) {
        addRunner(runner)
    }

    func removeRunner(_ id: String) {
        runners.removeValue(forKey: id)
        Task {
            let actor = await RealmActor.shared()
            let path = await actor.getFrozenRunner(id)?.executable?.filePath ?? executeableURL(for: id)
            try? FileManager.default.removeItem(at: path)
            await actor.deleteRunner(id)
        }
    }
}

// MARK: - Import

extension DaisukeEngine {
    @MainActor
    func importRunner(from url: URL) async throws {
        try await downloadCommonsIfNecessary()
        if url.isFileURL {
            try await handleFileRunnerImport(from: url)
        } else {
            try await handleNetworkRunnerImport(from: url)
        }
        StateManager.shared.runnerListPublisher.send()
    }

    @MainActor
    func importRunner(from url: URL, with id: String) async throws {
        let list = try await getRunnerList(at: url)

        let runner = list.runners.first(where: { $0.id == id || $0.path == id })

        guard let runner = runner else {
            return
        }

        try await DSK.shared.saveRunnerList(at: url.absoluteString)
        let path = url
            .appendingPathComponent("runners")
            .appendingPathComponent("\(runner.path).stt")
        
        try await handleNetworkRunnerImport(from: path, with: url)
        StateManager.shared.runnerListPublisher.send()
    }

    private func handleFileRunnerImport(from url: URL) async throws {
        let runner = try await startRunner(url) // Start up
        try await validateRunnerVersion(runner: runner) // check if is new version

        let runnerPath = executeableURL(for: runner.id)
        _ = try FileManager.default.replaceItemAt(runnerPath, withItemAt: url)
        await upsertStoredRunner(runner)
        didStartRunner(runner)
    }

    private func upsertStoredRunner(_ runner: AnyRunner, listURL: URL? = nil) async {
        let actor = await RealmActor.shared()
        await actor.saveRunner(runner, listURL: listURL, url: executeableURL(for: runner.id))
    }
}

// MARK: - Network Import

extension DaisukeEngine {
    func getRunnerList(at url: URL) async throws -> RunnerList {
        let listUrl = url.lastPathComponent == "runners.json" ? url : url.runnersListURL
        let req = URLRequest(url: listUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        let task = AF.request(req).validate().serializingDecodable(RunnerList.self)

        let runnerList = try await task.value
        return runnerList
    }

    // Get Source List Info
    func saveRunnerList(at url: String) async throws {
        let hasHttpPrefix = url.hasPrefix("http") || url.hasPrefix("https")
        let builtUrl = hasHttpPrefix ? url : "https://\(url)"
        // Get runner list
        let base = URL(string: builtUrl)
        guard let base else {
            throw DSK.Errors.NamedError(name: "Validation", message: "Invalid URL")
        }
        let runnerList = try await getRunnerList(at: base)
        let actor = await RealmActor.shared()
        await actor.saveRunnerList(runnerList, at: base)
    }

    // Handle Importing Runner File from Internet
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

        let runner = try await startRunner(downloadURL)
        try await validateRunnerVersion(runner: runner)

        let runnerPath = executeableURL(for: runner.id)
        _ = try FileManager.default.replaceItemAt(runnerPath, withItemAt: downloadURL)
        try? FileManager.default.removeItem(at: downloadURL)
        addRunner(runner, listURL: list)
        await upsertStoredRunner(runner, listURL: list)
    }
}

// MARK: - Commons

extension DaisukeEngine {
    private func downloadCommonsIfNecessary() async throws {
        let base = URL(string: "https://suwatte.github.io/Common")!
        var url = base.appendingPathComponent("versioning.json")

        let data = try await AF
            .request(url) { $0.timeoutInterval = 2.5 } // Timeout in 2.5 Seconds.
            .validate()
            .serializingDecodable(DSKCommon.JSCommon.self)
            .value

        let saved = UserDefaults.standard.string(forKey: STTKeys.JSCommonsVersion)

        // download if commons is not installed, version not saved to UD or commons is out of date
        let download = !commons.exists || saved == nil || [ComparisonResult.orderedDescending].contains(data.version.compare(saved!))

        guard download else { return }

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
    }
}

// MARK: - Source Management

extension DaisukeEngine {
    func getSource(id: String) async -> AnyContentSource? {
        let runner = await getRunner(id)

        guard let runner, let source = runner as? AnyContentSource else { return nil }
        return source
    }

    func getContentSource(id: String) async throws -> AnyContentSource {
        let runner = try await getDSKRunner(id)

        guard let source = runner as? AnyContentSource else {
            throw DSK.Errors.InvalidRunnerEnvironment
        }

        return source
    }

    func getActiveSources() async -> [AnyContentSource] {
        let actor = await RealmActor.shared()
        let runners = await actor.getSavedAndEnabledSources().map(\.id)

        let sources = await withTaskGroup(of: AnyContentSource?.self, body: { group in
            for runner in runners {
                group.addTask {
                    await self.getSource(id: runner)
                }
            }

            var sources: [AnyContentSource] = []
            for await runner in group {
                guard let runner else { continue }
                sources.append(runner)
            }

            return sources
        })

        return sources
            .sorted(by: \.name)
    }

    func getSourcesForSearching() async -> [AnyContentSource] {
        let disabled: Set<String> = Preferences.standard.disabledGlobalSearchSources

        return await getActiveSources()
            .filter { !disabled.contains($0.id) }
    }

    func getSourcesForLinking() async -> [AnyContentSource] {
        await getSourcesForSearching()
            .filter { $0.ablityNotDisabled(\.disableContentLinking) }
    }

    func getSourcesForUpdateCheck() async -> [AnyContentSource] {
        await getActiveSources()
            .filter { $0.ablityNotDisabled(\.disableUpdateChecks) }
    }
}

// MARK: - Tracker Management

extension DaisukeEngine {
    func getTracker(id: String) async -> AnyContentTracker? {
        let runner = await getRunner(id)

        guard let runner, let tracker = runner as? AnyContentTracker else { return nil }
        return tracker
    }

    func getContentTracker(id: String) async throws -> AnyContentTracker {
        let runner = try await getDSKRunner(id)

        guard let tracker = runner as? AnyContentTracker else {
            throw DSK.Errors.InvalidRunnerEnvironment
        }

        return tracker
    }

    func getActiveTrackers() async -> [AnyContentTracker] {
        let actor = await RealmActor.shared()
        let runners = await actor.getEnabledRunners(for: .tracker).map(\.id)

        let trackers = await withTaskGroup(of: AnyContentTracker?.self, body: { [runners] group in
            for runner in runners {
                group.addTask {
                    await self.getTracker(id: runner)
                }
            }

            var trackers: [AnyContentTracker] = []
            for await runner in group {
                guard let runner else { continue }
                trackers.append(runner)
            }

            return trackers
        })

        return trackers
            .sorted(by: \.name)
    }

    func getTrackersHandling(key: String) async -> [AnyContentTracker] {
        await getActiveTrackers()
            .filter { $0.config?.linkKeys?.contains(key) ?? false }
    }

    /// Gets a map of  TrackerLInkKey:MediaID and coverts it to a TrackerID:MediaID dict
    func getTrackerHandleMap(values: [String: String]) async -> [String: String] {
        var matches: [String: String] = [:]

        // Loop through links and get matching sources
        for (key, value) in values {
            let trackers = await getActiveTrackers()
                .filter { $0.links.contains(key) }

            // Trackers that can handle this link
            for tracker in trackers {
                guard matches[tracker.id] == nil else { continue }
                matches[tracker.id] = value
            }
        }

        return matches
    }
}
