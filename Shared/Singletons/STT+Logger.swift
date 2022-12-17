//
//  STT+Logger.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-27.
//

import Foundation
import SwiftUI

class Logger: ObservableObject {
    @Published var logs: [Entry] = []
    static let shared = Logger()

    var file: URL {
        FileManager.default.documentDirectory.appendingPathComponent("application_logs.txt", isDirectory: false)
    }

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
    enum Level: Int, Codable {
        case base
        case debug
        case error
    }

    struct Entry: Codable {
        var timestamp = Date()
        var message: String
        var level: Level = .base
        var context: Context?
    }

    struct Context: Codable {
        var file: String?
        var function: String?
        var line: Int?
    }
}

extension Logger {
    private func add(entry: Entry) {
        // Add Entry
        if logs.count >= 100 {
            logs.removeAll()
        }
        logs.append(entry)

        // Print to console in debugging
        #if DEBUG
            print(entry.OutputMessage)
        #endif

        // Write to File
        Task {
            write(entry: entry)
        }
    }

    private func write(entry: Entry) {
        let log = entry.OutputMessage

        do {
            try log.appendLineToURL(url: file)
        } catch {
            print(error)
            logs.append(.init(message: "Failed to write log to file, \(error.localizedDescription)", level: .error))
        }
    }
}

// MARK: Logger Functions

extension Logger {
    func log(level: Level = .base, _ message: String, _ context: Context? = nil) {
        add(entry: .init(message: message, level: level, context: context))
    }

    func debug(_ message: String, _ context: Context? = nil) {
        log(level: .debug, message, context)
    }

    func error(_ message: String, _ context: Context? = nil) {
        log(level: .error, message, context)
    }
}

// MARK: Log String

extension Logger.Entry {
    var FullMessage: String {
        var str = message

        if let ctx = context?.description {
            str += " -> \(ctx)"
        }

        return str
    }

    var OutputMessage: String {
        "\(level.description)" + " [\(timestamp.description)] " + FullMessage
    }

    var DisplayMessage: String {
        "\(level.description) \(FullMessage)"
    }
}

extension Logger.Context {
    var description: String {
        var str = ""

        if let file {
            str += (file as NSString).lastPathComponent + ":"
        }
        if let line {
            str += line.description
        }

        if let function {
            str += " \(function) "
        }

        return str
    }
}

// MARK: Level

extension Logger.Level {
    var description: String {
        switch self {
        case .base:
            return ""
        case .debug:
            return "[DEBUG]"
        case .error:
            return "[ERROR]"
        }
    }

    var color: Color {
        switch self {
        case .base:
            return .gray
        case .debug:
            return .blue
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
