//
//  Logger.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-27.
//

import Alamofire
import Foundation
import SwiftUI

final class Logger {
    @MainActor var logs: [Entry] = []
    static let shared = Logger()

    var file: URL {
        FileManager.default.documentDirectory.appendingPathComponent("application_logs.txt", isDirectory: false)
    }

    @MainActor
    func clearSession() {
        logs.removeAll()
    }

    func clearFile() {
        let str = ""
        try? str.write(to: file, atomically: true, encoding: .utf8)
    }
}

// MARK: Objects

extension Logger {
    enum Level: String, Codable {
        case log = "LOG"
        case info = "INFO"
        case debug = "DEBUG"
        case warn = "WARN"
        case error = "ERROR"
    }

    struct Entry: Codable, Identifiable {
        var timestamp = Date()
        var message: String
        var level: Level = .log
        var context: String = ""
        var id = UUID().uuidString
    }
}

extension Logger {
    private func add(entry: Entry) {
        var entry = entry
        let devMode = UserDefaults.standard.bool(forKey: STTKeys.RunnerDevMode)
        // Limit msg to 3000 chars
        if !devMode && entry.message.count >= 3000 {
            entry.message = entry.message.subString(from: 0, to: 3000)
            + "\r\n Suwatte: The log is longer than 3000 characters and was cut. Enable developer mode to see the full message!"
        }
        let localEntry = entry

        Task { @MainActor in
            // Add Entry
            if logs.count >= 100 {
                logs.removeAll()
            }
            logs.append(localEntry)
        }

        // Print to console in debugging
        #if DEBUG
            print(entry.OutputMessage)
        #endif

        // Write to File
        Task {
            write(entry: localEntry)
        }

        if entry.level == .info {
            ToastManager.shared.info(localEntry.message)
        }

        Task {

            let logAddress = UserDefaults.standard.string(forKey: STTKeys.LogAddress)

            guard devMode, let logAddress, let address = URL(string: logAddress) else { return }

            do {
                var request = URLRequest(url: address)
                request.method = .post
                request.httpBody = try DSK.encode(value: localEntry)
                AF.request(request).response { _ in
                    //
                }
            } catch {}
        }
    }

    private func write(entry: Entry) {
        let log = entry.OutputMessage

        do {
            try log.appendLineToURL(url: file)
        } catch {
            Task { @MainActor in
                logs.append(.init(message: "Failed to write log to file, \(error.localizedDescription)", level: .error))
            }
        }
    }
}

// MARK: Logger Functions

extension Logger {
    func log(level: Level = .log, _ message: String, _ context: String = "") {
        Task { @MainActor in
            add(entry: .init(message: message, level: level, context: context))
        }
    }

    func info(_ message: String, _ context: String = "") {
        log(level: .info, message, context)
    }

    func debug(_ message: String, _ context: String = "") {
        log(level: .debug, message, context)
    }

    func warn(_ message: String, _ context: String = "") {
        log(level: .warn, message, context)
    }

    func error(_ message: String, _ context: String = "") {
        log(level: .error, message, context)
    }

    func error(_ error: Error, _ context: String = "") {
        self.error("\(error)", context)
    }
}

// MARK: Log String

extension Logger.Entry {
    var OutputMessage: String {
        var out = ""
        out += "[\(level.rawValue)] [\(timestamp.formatted())] "
        if !context.isEmpty {
            out += "[\(context)] "
        }
        out += message

        return out
    }
}

// MARK: Level

extension Logger.Level {
    var color: Color {
        switch self {
        case .log:
            return .gray
        case .info:
            return .green
        case .debug:
            return .blue
        case .warn:
            return .yellow
        case .error:
            return .red
        }
    }
}

// MARK: Needed Extensions

// Reference : https://stackoverflow.com/a/40687742
extension String {
    func appendLineToURL(url: URL) throws {
        try (self + "\n").appendToURL(url: url)
    }

    func appendToURL(url: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(url: url)
    }
}

extension Data {
    func append(url: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: url.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: url, options: .atomic)
        }
    }
}
