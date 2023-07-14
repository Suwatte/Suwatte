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

final class DaisukeEngine: NSObject {
    // MARK: Singleton
    static let shared = DaisukeEngine()
    
    private let directory = FileManager
        .default
        .applicationSupport
        .appendingPathComponent("Runners", isDirectory: true)
    
    internal var commons: URL {
        directory
            .appendingPathComponent("common.js")
    }
    
    private var runners: [String: JSCRunner] = [:]
    private let vm: JSVirtualMachine
    
    override init() {
        // Create Directory if required
        if !directory.exists {
            directory.createDirectory()
        }
        
        // Start VM
        let queue = DispatchQueue(label: "com.ceres.suwatte.daisuke", attributes: .concurrent)
        vm = queue.sync { JSVirtualMachine()! }
        
        // Simple Log Message
        Logger.shared.log(level: .log, "Engine Ready!", "DaisukeEngine")
    }
}

// MARK: - Helpers
extension DaisukeEngine {
    private func executeableURL(for id: String) -> URL {
        let fileName = STTHelpers.sha256(of: id) + ".stt"
        let file = directory
            .appendingPathComponent(fileName)
        return file
    }
    
    private func validateRunnerVersion(runner: JSCRunner) throws {
        // Validate that the incoming runner has a higher version
        let current = getRunner(runner.id)
        
        if let current = current, current.version > runner.version {
            throw DSK.Errors.NamedError(name: "Validation", message: "An updated version is already installed.")
        }
    }
}

// MARK: - Bootstrap
extension DaisukeEngine {
    private func newJSCContext() -> JSContext {
        JSContext(virtualMachine: vm)!
    }
    
    private func add(class cls: AnyClass, name: String, context: JSContext) {
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
    
    
    
    internal func bootstrap(_ scriptURL: URL) throws -> JSValue {
        // Generate New Context
        let context = newJSCContext()
        
        // Required File Routes
        let commonsPath =            FileManager
            .default
            .applicationSupport
            .appendingPathComponent("Runners", isDirectory: true)
            .appendingPathComponent("common.js")
        
        let messageHandlerFiles = [
            Bundle.main.url(forResource: "log", withExtension: "js")!,
            Bundle.main.url(forResource: "store", withExtension: "js")!,
            Bundle.main.url(forResource: "network", withExtension: "js")!,
        ]
        
        let bootstrapFile = Bundle.main.url(forResource: "bridge", withExtension: "js")!
        
        
        // Declare Intial ID
        context.globalObject.setValue(scriptURL.fileName, forProperty: "IDENTIFIER")
        // Evaluate Commons Script
        var content = try String(contentsOf: commonsPath, encoding: .utf8)
        _ = context.evaluateScript(content)
        
        // Inject Handlers
        add(class: JSCHandler.LogHandler.self, name: "LogHandler", context: context)
        add(class: JSCHandler.StoreHandler.self, name: "StoreHandler", context: context)
        add(class: JSCHandler.NetworkHandler.self, name: "NetworkHandler", context: context)
        
        // Evalutate Runner Script
        content = try String(contentsOf: scriptURL, encoding: .utf8)
        _ = context.evaluateScript(content)
        
        // Evaluate Message Handler Scripts
        for url in messageHandlerFiles {
            content = try String(contentsOf: url, encoding: .utf8)
            _ = context.evaluateScript(content)
        }
        
        // Evaluate Bootstrap Script
        content = try String(contentsOf: bootstrapFile, encoding: .utf8)
        _ = context.evaluateScript(content)
        
        
        let runner = context.daisukeRunner()
        guard let runner, runner.isObject else {
            throw DSK.Errors.RunnerClassInitFailed
        }
        
        return runner
    }
    

}
// MARK: - Runner Start Up
extension DaisukeEngine {
    
    func startRunner(_ id: String) throws -> JSCRunner {
        
        let file = DataManager.shared.getRunnerExecutable(id: id)
        
        guard let file, file.exists else {
            let standardLocation = executeableURL(for: id)
            if standardLocation.exists {
                return try startRunner(standardLocation)
            } else {
                throw DSK.Errors.RunnerExecutableNotFound
            }
        }
        
        return try startRunner(file)
    }
    
    func startRunner(_ url: URL) throws -> JSCRunner {
        // Get Core Runner Object
        let runnerObject = try bootstrap(url)
        
        // Get Runner Environment
        let environment = runnerObject
            .context!
            .evaluateScript("(function(){ return RunnerEnvironment })()")
            .toString()
            .flatMap(DSKCommon.RunnerEnvironment.init(rawValue:)) ?? .unknown
        var runner: JSCRunner? = nil
        switch environment {
        case .source:
            runner = try JSCCS(value: runnerObject)
            break
        case .tracker:
            runner = try JSCContentTracker(value: runnerObject)
            break
        default:
            break
        }
        
        guard let runner else {
            throw DSK.Errors.NamedError(name: "Engine", message: "Failed to recognize runner environment.")
        }
        
        didStartRunner(runner)
        return runner
    }
}
// MARK: - Runner Management
extension DaisukeEngine {
    func getJSCRunner(_ id: String) throws -> JSCRunner {
        return try runners[id] ?? startRunner(id)
    }
    
    func getRunner(_ id: String) -> JSCRunner? {
        do {
            return try getJSCRunner(id)
        } catch {
            Logger.shared.error("[\(id)] [Requested] \(error.localizedDescription)")
            return nil
        }
    }
    
    func addRunner(_ rnn: JSCRunner, listURL: URL? = nil) {
        runners.removeValue(forKey: rnn.id)
        runners[rnn.id] = rnn
        DataManager.shared.saveRunner(rnn.info, listURL: listURL, url: executeableURL(for: rnn.id), environment: rnn.environment)
    }
    
    func didStartRunner(_ runner: JSCRunner) {
        addRunner(runner)
    }
    
    func removeRunner(_ id: String) {
        runners.removeValue(forKey: id)

        // Remove From Realm
        DataManager.shared.deleteRunner(id)

        // Delete .STT File If present
        Task {
            let path = executeableURL(for: id)
            try? FileManager.default.removeItem(at: path)
        }
    }
}
// MARK: - Import
extension DaisukeEngine {
    @MainActor
    func importRunner(from url: URL) async throws {
        try await downloadCommonsIfNecessary()
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
    
    
    private func handleFileRunnerImport(from url: URL) throws {
        let runner = try startRunner(url) // Start up
        try validateRunnerVersion(runner: runner) // check if is new version
        
        
        let runnerPath = executeableURL(for: runner.id)
        _ = try FileManager.default.replaceItemAt(runnerPath, withItemAt: url)
        
        Task { @MainActor in
            didStartRunner(runner)
        }
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
        // Get runner list
        let base = URL(string: url)
        guard let base else {
            throw DSK.Errors.NamedError(name: "Validation", message: "Invalid URL")
        }
        let runnerList = try await getRunnerList(at: base)
        DataManager.shared.saveRunnerList(runnerList, at: base)
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
        
        let runner = try startRunner(downloadURL)
        try validateRunnerVersion(runner: runner)
        
        let runnerPath = executeableURL(for: runner.id)
        _ = try FileManager.default.replaceItemAt(runnerPath, withItemAt: downloadURL)
        try? FileManager.default.removeItem(at: downloadURL)
        addRunner(runner, listURL: list)
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
    
    func getSource(id: String) -> JSCContentSource? {
        let runner = getRunner(id)
        
        guard let runner, let source = runner as? JSCCS else { return nil }
        return source
    }

    func getContentSource(id: String) throws -> JSCContentSource {
        let runner = try getJSCRunner(id)
        
        guard let source = runner as? JSCCS else {
            throw DSK.Errors.InvalidRunnerEnvironment
        }
        
        return source
    }
    
    func getActiveSources() -> [AnyContentSource] {
        DataManager
            .shared
            .getSavedAndEnabledSources()
            .compactMap { DSK.shared.getSource(id: $0.id) }
    }
}


// MARK: - Tracker Management

extension DaisukeEngine {
    
    func getTracker(id: String) -> JSCCT? {
        let runner = getRunner(id)
        
        guard let runner, let tracker = runner as? JSCCT else { return nil }
        return tracker
    }
    
    func getContentTracker(id: String) throws -> JSCCT {
        let runner = try getJSCRunner(id)
        
        guard let tracker = runner as? JSCCT else {
            throw DSK.Errors.InvalidRunnerEnvironment
        }
        
        return tracker
    }
    
    func getActiveTrackers() -> [JSCCT] {
        DataManager
            .shared
            .getEnabledRunners(for: .tracker)
            .compactMap { DSK.shared.getTracker(id: $0.id) }
    }
    
    func getTrackersHandling(key: String) -> [JSCCT] {
        getActiveTrackers()
            .filter { $0.config?.linkKeys?.contains(key) ?? false }
    }
    
    /// Gets a map of  TrackerLInkKey:MediaID and coverts it to a TrackerID:MediaID dict
    func getTrackerHandleMap(values: [String: String]) -> [String: String] {
        var matches: [String: String] = [:]
        
        // Loop through links and get matching sources
        for (key, value) in values {
            let trackers = getActiveTrackers()
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
