//
//  STTToastManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-28.
//

import Foundation


@MainActor
final class ToastManager2: ObservableObject {
    private var queue: Queue<Entry> = .init()
    private var task: Task<Void, Never>?
    @Published var toast: Entry? = nil
    @Published var loading: Bool = false

    fileprivate func run() {
        let message = queue.head
        guard let message else { return }

        task?.cancel()
        task = Task {
            try? await Task.sleep(seconds: 0.3)
            toast = message
            print("Set \(message)")
            try? await Task.sleep(seconds: 10)
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
extension ToastManager2 {
    enum ToastType {
        case info( _ msg: String)
        case error(_ error: Error? = nil, _ msg: String = "An Error Occurred")
    }
    
    struct Entry: Equatable {
        var id = UUID().uuidString
        var type: ToastType
        
        
        static func == ( lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
}


// MARK: Functions
extension ToastManager2 {
    private var busy: Bool {
        queue.head != nil || toast != nil
    }
    func display(_ type: ToastType) {
        let busy = busy
        queue.enqueue(.init(type: type))
        
        if !busy { run() }
    }
}
