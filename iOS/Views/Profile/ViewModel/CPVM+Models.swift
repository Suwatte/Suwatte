//
//  CPVM+Models.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation
private typealias ViewModel = ProfileView.ViewModel

extension ViewModel {
    struct ContentLinkSection {
        let source: AnyContentSource
        let chapters: [ThreadSafeChapter]
        let maxOrderKey: Double
    }
}

extension ViewModel {
    enum SyncState: Hashable {
        case idle, syncing, done
    }
}

extension ViewModel {
    struct ActionState: Hashable {
        var state: ProgressState
        var chapter: ThreadSafeChapter?
        var marker: Marker?

        struct Marker: Hashable {
            var progress: Double
            var date: Date?
        }
    }

    enum ProgressState: Int, Hashable {
        case none, start, resume, bad_path, reRead, upNext, restart

        var description: String {
            switch self {
            case .none:
                return " - "
            case .start:
                return "Start"
            case .resume:
                return "Resume"
            case .bad_path:
                return "Chapter not Found"
            case .reRead:
                return "Re-read"
            case .upNext:
                return "Up Next"
            case .restart:
                return "Restart"
            }
        }
    }
}
