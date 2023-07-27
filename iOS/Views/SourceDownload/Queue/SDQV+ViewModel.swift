//
//  SDQV+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-26.
//

import Foundation
import RealmSwift
import SwiftUI

extension SourceDownloadQueueView {
    final class ViewModel: ObservableObject {
        @Published var isWorking = true
        @Published var data = [[SourceDownload]]()
        @Published var initialDataFetchComplete = false
        private let visisble: [DownloadStatus] = [.queued, .paused, .failing]

        private var token: NotificationToken?
    }
}

extension SourceDownloadQueueView.ViewModel {
    func watch() {
        stop()

        let realm = try! Realm()

        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.content != nil && $0.chapter != nil }
            .where { $0.status.in(visisble) }
            .sectioned(by: \.content?.id, sortDescriptors: [.init(keyPath: "content.id"), .init(keyPath: "dateAdded", ascending: true)])

        token = collection.observe { _ in
            let build = collection.map { Array($0.freeze()) }
            Task { @MainActor in
                withAnimation {
                    self.data = build

                    if !self.initialDataFetchComplete {
                        self.initialDataFetchComplete = true
                    }
                }
            }
        }
    }

    func stop() {}
}
