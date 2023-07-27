//
//  SDV+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation
import RealmSwift
import SwiftUI

extension SourceDownloadView {
    final class ViewModel: ObservableObject {
        @Published var entries = [SourceDownloadIndex]()
        @Published var working = true
        @Published var text = ""
        @Published var initialFetchComplete = false

        private var token: NotificationToken?
    }
}

extension SourceDownloadView.ViewModel {
    func watch(_ sort: SourceDownloadView.SortOption, _ ascending: Bool) {
        stop()
        withAnimation {
            working = true
        }

        let realm = try! Realm()

        var collection = realm
            .objects(SourceDownloadIndex.self)
            .where { $0.content != nil && $0.count > 0 }

        switch sort {
        case .title:
            collection = collection.sorted(by: \.content?.title, ascending: ascending)
        case .downloadCount:
            collection = collection.sorted(by: \.count, ascending: ascending)
        case .dateAdded:
            collection = collection.sorted(by: \.dateLastAdded, ascending: ascending)
        }
        //
        if !text.isEmpty {
            collection = collection
                .filter("ANY content.additionalTitles CONTAINS[cd] %@ OR content.title CONTAINS[cd] %@ OR content.summary CONTAINS[cd] %@", text, text, text)
        }

        token = collection
            .observe { _ in
                let mapped = collection
                    .freeze()
                    .toArray()

                Task { @MainActor in
                    withAnimation {
                        self.working = false
                        self.entries = mapped

                        if !self.initialFetchComplete {
                            self.initialFetchComplete.toggle()
                        }
                    }
                }
            }
    }

    func stop() {
        token?.invalidate()
        token = nil
    }
}
