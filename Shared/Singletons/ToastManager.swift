//
//  ToastManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-28.
//

import Foundation

final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    private var queue: Queue<Entry> = .init()
    private var task: Task<Void, Never>?
    @Published var toast: Entry? = nil
    @Published var loading: Bool = false

    fileprivate func run() {
        let message = queue.head
        guard let message else { return }

        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(seconds: 0.3)
            toast = message
            try? await Task.sleep(seconds: 3)
            toast = nil
            queue.dequeue()
            run()
        }
    }

    func cancel() {
        task?.cancel()
        toast = nil
    }
}

// MARK: Models

extension ToastManager {
    enum ToastType {
        case info(_ msg: String)
        case error(_ error: Error? = nil, _ msg: String = "An Error Occurred")
    }

    struct Entry: Equatable {
        var id = UUID().uuidString
        var type: ToastType

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
}

// MARK: Functions

extension ToastManager {
    private var busy: Bool {
        queue.head != nil || toast != nil
    }

    func display(_ type: ToastType) {
        let busy = busy
        queue.enqueue(.init(type: type))

        if !busy { run() }

        Task {
            let context = "[ToastManager]"
            switch type {
            case let .info(msg):
                Logger.shared.log("\(context) \(msg)")
            case let .error(err, msg):
                if let err {
                    Logger.shared.error("\(context) [Duplicate] \(err)")
                } else {
                    Logger.shared.error("\(context) \(msg)")
                }
            }
        }
    }

    func info(_ str: String) {
        display(.info(str))
    }

    func error(_ error: Error) {
        display(.error(error))
    }

    func error(_ error: String) {
        display(.error(nil, error))
    }
}
