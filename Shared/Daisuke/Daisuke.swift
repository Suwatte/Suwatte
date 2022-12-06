//
//  Daisuke.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Alamofire
import Foundation
import JavaScriptCore
import RealmSwift

final class DaisukeEngine: ObservableObject {
    // MARK: Singleton

    static let shared = DaisukeEngine()

    // MARK: Virtual Machine

    private let vm: JSVirtualMachine
    private let STT_EV = "[DAISUKE]"

    // MARK: Directory

    private let directory = FileManager
        .default
        .documentDirectory
        .appendingPathComponent("DaisukeRunners", isDirectory: true)

    internal var commons: URL {
        directory
            .appendingPathComponent("common.js")
    }

    // MARK: Runners
    @Published var sources: [String: DaisukeContentSource] = [:]

    init() {
        // Start Virtual Machine
        let queue = DispatchQueue(label: "com.suwatte.daisuke")
        vm = queue.sync { JSVirtualMachine()! }

        // Create Directory
        directory.createDirectory()
        Logger.shared.log("\(STT_EV) Daisuke Engine Started.")
        Task { @MainActor in
            do {
                try await getDependencies()
                startRunners()
            } catch {
                ToastManager.shared.error("Failed to Start Runners")
                Logger.shared.error("\(error)")
            }
            ToastManager.shared.loading = false
        }
    }
}

// MARK: Context Creation

extension DaisukeEngine {
    private func newJSContext() -> JSContext {
        let context = JSContext(virtualMachine: vm)!
        injectCommonLibraries(context)
        injectDataClases(context)
        injectLogger(context)
        return context
    }

    private func timeMethod(_ action: @escaping () async throws -> Void) async throws {
        let start = DispatchTime.now() // <<<<<<<<<< Start time
        try await action()
        let end = DispatchTime.now() // <<<<<<<<<<   end time

        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
        let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests

        Logger.shared.debug("Evaluated in \(timeInterval) seconds")
    }
}

// MARK: Init Runners

extension DaisukeEngine {
    private func startRunners() {
        let urls = try? FileManager
            .default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.isFileURL }

        guard let urls = urls?.filter({ $0.lastPathComponent.contains(".stt") }) else {
            return
        }
        for url in urls {
            do {
                let runner = try startRunner(at: url)
                try addSource(runner: runner)
                Logger.shared.log("\(STT_EV) Started \(runner.name)")
            } catch {
                ToastManager.shared.error(error)
            }
        }
        
        startHostedRunners()
    }
    
    private func startHostedRunners() {
        
        let hostedRunners = DataManager.shared.getHostedRunners()
        
        for runner in hostedRunners {
            do {
                guard let str = runner.info, let data = str.data(using: .utf8), let strUrl = runner.listURL, let url = URL(string: strUrl) else {
                    ToastManager.shared.error(DSK.Errors.NamedError(name: "StartUp Error", message: "Invalid Source Info"))
                    return
                }
                let info = try DaisukeEngine.decode(data: data, to: ContentSourceInfo.self)
                let source = HostedContentSource(host: url, info: info)
                try addSource(runner: source)
                
            } catch {
                ToastManager.shared.error(error)
            }
        }
    }

    private func startRunner(at path: URL) throws -> DaisukeContentSource {
        let context = newJSContext()
        let content = try String(contentsOfFile: path.relativePath, encoding: String.Encoding.utf8)

        // Evaluate Script
        _ = context.evaluateScript("let ASSETS_DIRECTORY = '';")
        _ = context.evaluateScript(content)
        _ = context.evaluateScript("const DAISUKE_RUNNER = new STTPackage.Target();")
        let runnerClass = context.daisukeRunner()

        guard let runnerClass = runnerClass, runnerClass.isObject else {
            throw Errors.RunnerClassInitFailed
        }
        

        let source = try LocalContentSource(runnerClass: runnerClass)
        if let url = DataManager.shared.getRunnerInfomation(id: source.id)?.listURL {
            let val = url + "/assets"
            _ = context.evaluateScript("ASSETS_DIRECTORY = '\(val)';")
        }
        return source
    }

    private func validateRunnerVersion(runner: DaisukeContentSource) throws {
        // Validate that the incoming runner has a higher version
        let current = sources[runner.id]

        if let current = current, current.version > runner.version {
            throw Errors.NamedError(name: "DAISUKE", message: "Current Installed Version is Higher")
        }
    }

    private func addSource(runner: DaisukeContentSource) throws {
        sources.removeValue(forKey: runner.id)
        sources.updateValue(runner, forKey: runner.id)
        if let runner = runner as? LocalContentSource {
            Task {
                try? await runner.registerDefaultPrefs()
                await runner.onSourceLoaded()
            }
        }
    }

    func removeRunner(id: String) throws {
        sources.removeValue(forKey: id)
        DataManager.shared.removeRunnerInformation(id: id)
        let path = directory.appendingPathComponent("\(id).stt")
        try FileManager.default.removeItem(at: path)
    }
}

extension DaisukeEngine {
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
            .appendingPathComponent("runners")
            .appendingPathComponent("\(runner.path).stt")
        try await handleNetworkRunnerImport(from: path)
    }

    private func handleFileRunnerImport(from url: URL) throws {
        let runner = try startRunner(at: url)
        try validateRunnerVersion(runner: runner)
        let validRunnerPath = directory.appendingPathComponent("\(runner.id).stt")
        let _ = try FileManager.default.replaceItemAt(validRunnerPath, withItemAt: url)
        try addSource(runner: runner)
    }

    private func handleNetworkRunnerImport(from url: URL) async throws {
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        let path = url.lastPathComponent
        let tempLocation = directory
            .appendingPathComponent("__temp__")
            .appendingPathComponent(path)

        let destination: DownloadRequest.Destination = { _, _ in
            (tempLocation, [.removePreviousFile, .createIntermediateDirectories])
        }
        let request = AF.download(req, to: destination)

        let downloadURL = try await request.serializingDownloadedFileURL().result.get()

        let runner = try startRunner(at: downloadURL)

        try validateRunnerVersion(runner: runner)
        let validRunnerPath = directory.appendingPathComponent("\(runner.id).stt")
        let _ = try FileManager.default.replaceItemAt(validRunnerPath, withItemAt: downloadURL)
        try? FileManager.default.removeItem(at: downloadURL)
        try await MainActor.run(body: {
            try addSource(runner: runner)
        })
    }
    
    func saveHostedRunner(list: String, runner: Runner) {
        let realm = try! Realm()
        
        do {
            let data = try DaisukeEngine.encode(value: runner)
            let str = String(decoding: data, as: UTF8.self)
            
            let obj = StoredRunnerObject()
            obj.id = runner.id
            obj.hosted = true
            obj.listURL = list
            obj.info = str
            obj.name = runner.name
            obj.thumbnail = runner.thumbnail
            
            try! realm.safeWrite {
                realm.add(obj, update: .modified)
            }
            
            let source = HostedContentSource(host: URL(string: list)!, info: .init(id: runner.id, name: runner.name, version: runner.version, website: runner.website ?? "", supportedLanguages: runner.supportedLanguages ?? [], hasExplorePage: runner.hasExplorePage ?? false))
            try addSource(runner: source)
            
        } catch {
            ToastManager.shared.error(error)
        }
        
    }
}

extension JSContext {
    func daisukeRunner() -> JSValue? {
        return evaluateScript("(function(){ return DAISUKE_RUNNER })()")
    }
}

//// MARK: Fetch
extension DaisukeEngine {

    func getSource(with id: String) ->  DaisukeContentSource? {
       sources[id]
    }
    
    func getJSSource(with id: String) -> LocalContentSource? {
        sources[id] as? LocalContentSource
    }

    func getSources() -> [DaisukeContentSource] {
        sources.values.map({ $0 })
    }
}

// MARK: CommonLibrary

extension DaisukeEngine {
    func getDependencies() async throws {
        if commons.exists { return }

        await MainActor.run(body: {
            ToastManager.shared.loading = true
        })
        try await getCommons()
        await MainActor.run(body: {
            ToastManager.shared.info("Updated Commons")
        })
        
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
        let shouldRedownload = saved == nil || [ComparisonResult.orderedDescending].contains(data.version.compare(saved!)) || !commons.exists

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
    }
}
